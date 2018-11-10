# ~*~ encoding: utf-8 ~*~

require 'rugged'
require 'ostruct'
require 'mime-types'

module Gollum

  def self.set_git_timeout(time)
  end

  def self.set_git_max_filesize(size)
  end

  module Git

    DEFAULT_MIME_TYPE = "text/plain"
    class NoSuchShaFound < StandardError; end

    class Actor

      attr_accessor :name, :email

      def self.default_actor
        self.new("Gollum", "Gollum@wiki")
      end

      def initialize(name, email)
        @name = name
        @email = email
      end

      def output(time)
        # implementation from grit
        offset = time.utc_offset / 60
        "%s <%s> %d %+.2d%.2d" % [
        @name,
        @email || "null",
        time.to_i,
        offset / 60,
        offset.abs % 60]
      end

      def to_h
        {:name => @name, :email => @email}
      end

    end

    class Blob

      attr_reader :mode
      attr_reader :name
      attr_reader :id

      def self.create(repo, options)
        blob = repo.git.lookup(options[:id])
        self.new(blob, options)
      end

      def initialize(blob, options = {})
        @blob = blob
        @mode = options[:mode]
        @name = options[:name]
        @size = options[:size]
        @id = blob.oid
      end

      def data
        @content ||= @blob.content
      end

      def is_symlink
        @mode == 0120000
      end

      def mime_type
        guesses = MIME::Types.type_for(self.name) rescue []
        guesses.first ? guesses.first.simplified : DEFAULT_MIME_TYPE
      end

      def size
        @size || @blob.size
      end

      def symlink_target(base_path = nil)
        target = data
        new_path = ::File.expand_path(::File.join('..', target), base_path)
        return new_path if ::File.file? new_path
        nil
      end
    end

    class Commit

      def initialize(commit)
        @commit = commit
      end

      def id
        @commit.oid
      end
      alias_method :sha, :id
      alias_method :to_s, :id

      attr_reader :commit

      def author
        @author ||= Gollum::Git::Actor.new(@commit.author[:name], @commit.author[:email])
      end

      def authored_date
        @commit.author[:time]
      end

      def message
        @commit.message
      end

      def tree
        Gollum::Git::Tree.new(@commit.tree)
      end

      def stats
        @stats ||= build_stats
      end

      private

      def build_stats
        additions = 0
        deletions = 0
        total = 0
        files = []
        parent = @commit.parents.first
        diff = Rugged::Tree.diff(@commit.tree.repo, parent ? parent.tree : nil, @commit.tree)
        diff = diff.each_patch do |patch|
          new_additions = patch.stat[1]
          new_deletions = patch.stat[0]
          additions += new_additions
          deletions += new_deletions
          total += patch.changes
          files << [patch.delta.new_file[:path].force_encoding("UTF-8"), new_deletions, new_additions, patch.changes] # Rugged seems to generate the stat diffs in the other direciton than grit does by default, so switch the order of additions and deletions.
        end
        OpenStruct.new(:additions => additions, :deletions => deletions, :files => files, :id => id, :total => total)
      end

    end

    class Git

      # Rugged does not have a Git class, but the Repository class should allows us to do what's necessary.
      def initialize(repo)
        @repo = repo
      end

      def exist?
        ::File.exists?(@repo.path)
      end

      def grep(query, options={})
        ref = options[:ref] ? options[:ref] : "HEAD"
        tree = @repo.lookup(sha_from_ref(ref)).tree
        tree = @repo.lookup(tree[options[:path]][:oid]) if options[:path]
        enc = options.fetch(:encoding, 'utf-8')
        results = []
        tree.walk_blobs(:postorder) do |root, entry|
          blob = @repo.lookup(entry[:oid])
          count = 0
          next if blob.binary?
          blob.content.force_encoding(enc).each_line do |line|
            next unless line.match(/#{query}/i)
            count += 1
          end
          path = options[:path] ? ::File.join(options[:path], root, entry[:name]) : "#{root}#{entry[:name]}"
          results << {:name => path, :count => count} unless count == 0
        end
        results
      end

      def rm(path, options = {})
        index = @repo.index
        index.write
        ::File.unlink ::File.join(@repo.workdir, path)
      end

      def cat_file(options, sha)
        @repo.lookup(sha).read_raw
      end

      def apply_patch(head_sha = 'HEAD', patch=nil)
        false # Rewrite gollum-lib's revert so that it doesn't require a direct equivalent of Grit's apply_patch
      end

      def revert(path, sha1, sha2, ref)
        # FIXME: See https://github.com/gollum/grit_adapter/pull/14
        fail NotImplementedError
      end

      def checkout(path, ref = 'HEAD', options = {})
        path = path.nil? ? path : [path]
        options = options.merge({:paths => path, :strategy => :force})
        if ref == 'HEAD'
          @repo.checkout_head(options)
        else
          ref = "refs/heads/#{ref}" unless ref =~ /^refs\/heads\//
          @repo.checkout_tree(sha_from_ref(ref), options)
        end
      end

      def log(ref = 'refs/heads/master', path = nil, options = {})
        default_options = {
          :limit => options[:max_count] ? options[:max_count] : 10,
          :offset => options[:skip] ? options[:skip] : 0,
          :path => path,
          :follow => false,
          :skip_merges => false
        }
        options = default_options.merge(options)
        options[:limit] ||= 0
        options[:offset] ||= 0
        sha = sha_from_ref(ref)
        return [] if sha.nil?
        begin
          build_log(sha, options)
        rescue Rugged::OdbError, Rugged::InvalidError, Rugged::ReferenceError
        # Return an empty array if the ref wasn't found
          []
        end
      end

      def versions_for_path(path = nil, ref = nil, options = {})
        log(ref, path, options)
      end

      def ls_files(query, options = {})
        ref = options[:ref] || "refs/heads/master"
        tree = @repo.lookup(sha_from_ref(ref)).tree
        tree = @repo.lookup(tree[options[:path]][:oid]) if options[:path]
        results = []
        tree.walk_blobs do |root, blob|
          next unless blob[:name] =~ /#{query}/
          path = options[:path] ? ::File.join(options[:path], root, blob[:name]) : "#{root}#{blob[:name]}"
          results << path
        end
        results
      end

      def lookup(id)
        @repo.lookup(id)
      end

      def ref_to_sha(query)
        return query if sha?(query)
        query = "refs/heads/#{query}" if !query.nil? && !(query =~ /^refs\/heads\//) && !(query == "HEAD")
        begin
          return @repo.rev_parse_oid(query)
        rescue Rugged::ReferenceError, Rugged::InvalidError
          return nil
        end
      end

      def sha_or_commit_from_ref(ref, request_kind = nil)
        sha = ref_to_sha(ref)
        return nil if sha.nil?
        object = @repo.lookup(sha)
        if object.kind_of?(Rugged::Commit) then
          return Gollum::Git::Commit.new(object) if request_kind == :commit
          sha
        elsif object.respond_to?(:target)
          sha_or_commit_from_ref(object.target.oid, request_kind)
        end
      end
      alias_method :sha_from_ref, :sha_or_commit_from_ref

      def commit_from_ref(ref)
        sha_or_commit_from_ref(ref, :commit)
      end

      def push(remote, branches = nil, options = {})
        branches = [branches].flatten.map {|branch| "refs/heads/#{branch}" unless branch =~ /^refs\/heads\//}
        @repo.push(remote, branches, options)
      end

      def pull(remote, branches = nil, options = {})
        branches = [branches].flatten.map {|branch| "refs/heads/#{branch}" unless branch =~ /^refs\/heads\//}
        r = @repo.remotes[remote]
        r.fetch(branches, options)
        branches.each do |branch|
          branch_name = branch.match(/^refs\/heads\/(.*)/)[1]
          remote_name = remote.match(/^(refs\/heads\/)?(.*)/)[2]
          remote_ref = @repo.branches["#{remote_name}/#{branch_name}"].target
          local_ref = @repo.branches[branch].target
          index = @repo.merge_commits(local_ref, remote_ref)
          options = { author: Actor.default_actor.to_h,
            committer:  Actor.default_actor.to_h,
            message:    "Merged branch #{branch} of #{remote}.",
            parents: [local_ref, remote_ref],
            tree: index.write_tree(@repo),
            update_ref: branch
          }
          Rugged::Commit.create @repo, options
          @repo.checkout(@repo.head.name, :strategy => :force) if !@repo.bare? && branch == @repo.head.name
        end
      end

      private

      def sha?(str)
        !!(str =~ /^[0-9a-f]{40}$/)
      end

      # Return an array of log commits, given an SHA hash and a hash of
      # options. From Gitlab::Git
      def build_log(sha, options)
        # Instantiate a Walker and add the SHA hash
        walker = Rugged::Walker.new(@repo)
        walker.push(sha)
        commits = []
        skipped = 0
        current_path = options[:path]
        current_path = nil if current_path == ''
        limit = options[:limit].to_i
        offset = options[:offset].to_i
        skip_merges = options[:skip_merges]
        walker.sorting(Rugged::SORT_DATE)

          walker.each do |c|
            break if limit > 0 && commits.length >= limit
              if skip_merges
                # Skip merge commits
                next if c.parents.length > 1
              end

              if !current_path ||
                commit_touches_path?(c, current_path, options[:follow], walker)
                # This is a commit we care about, unless we haven't skipped enough
                # yet
                skipped += 1
                commits.push(Gollum::Git::Commit.new(c)) if skipped > offset
              end
          end
        walker.reset
        commits
      end

      # Returns true if +commit+ introduced changes to +path+, using commit
      # trees to make that determination. Uses the history simplification
      # rules that `git log` uses by default, where a commit is omitted if it
      # is TREESAME to any parent.
      #
      # If the +follow+ option is true and the file specified by +path+ was
      # renamed, then the path value is set to the old path.
      def commit_touches_path?(commit, path, follow, walker)
        entry = tree_entry(commit, path)

          if commit.parents.empty?
            # This is the root commit, return true if it has +path+ in its tree
            return entry != nil
          end

        num_treesame = 0
        commit.parents.each do |parent|
          parent_entry = tree_entry(parent, path)

          # Only follow the first TREESAME parent for merge commits
          if num_treesame > 0
            walker.hide(parent)
            next
          end

          if entry.nil? && parent_entry.nil?
            num_treesame += 1
          elsif entry && parent_entry && entry[:oid] == parent_entry[:oid]
            num_treesame += 1
          end
        end

        case num_treesame
          when 0
            detect_rename(commit, commit.parents.first, path) if follow
            true
          else false
        end
      end

      # Find the entry for +path+ in the tree for +commit+
      def tree_entry(commit, path)
        pathname = Pathname.new(path)
        tmp_entry = nil

        pathname.each_filename do |dir|
          tmp_entry = tmp_entry ? @repo.lookup(tmp_entry[:oid])[dir] : commit.tree[dir]
          return nil unless tmp_entry
        end
        tmp_entry
      end

      # Compare +commit+ and +parent+ for +path+. If +path+ is a file and was
      # renamed in +commit+, then set +path+ to the old filename.
      def detect_rename(commit, parent, path)
        diff = parent.diff(commit, paths: [path], disable_pathspec_match: true)

        # If +path+ is a filename, not a directory, then we should only have
        # one delta. We don't need to follow renames for directories.
        return nil if diff.each_delta.count > 1

        delta = diff.each_delta.first
        if delta.added?
          full_diff = parent.diff(commit)
          full_diff.find_similar!

          full_diff.each_delta do |full_delta|
            if full_delta.renamed? && path == full_delta.new_file[:path]
              # Look for the old path in ancestors
              path.replace(full_delta.old_file[:path])
            end
          end
        end
      end

    end

    class Index

      def initialize(index, repo)
        @index = index
        @rugged_repo = repo
        @treemap = {}
      end

      def delete(path)
        @index.remove_all(path)
        update_treemap(path, false)
        false
      end

      def add(path, data)
        blob = @rugged_repo.write(data, :blob)
        @index.add(:path => path, :oid => blob, :mode => 0100644)
        update_treemap(path, data)
        data
      end

      def index
        @index
      end

      def commit(message, parents = nil, actor = nil, last_tree = nil, head = 'refs/heads/master')
        commit_options = {}
        head = "refs/heads/#{head}" unless head =~ /^refs\/heads\//
        parents = get_parents(parents, head) || []
        actor = Gollum::Git::Actor.default_actor if actor.nil?
        commit_options[:tree] = @index.write_tree
        commit_options[:author] = actor.to_h
        commit_options[:committer] = actor.to_h
        commit_options[:message] = message.to_s
        commit_options[:parents] = parents
        commit_options[:update_ref] = head
        Rugged::Commit.create(@rugged_repo, commit_options)
      end

      def tree
        @treemap
      end

      def read_tree(id)
        id = Gollum::Git::Git.new(@rugged_repo).ref_to_sha(id)
        return nil if id.nil?
        current_tree = @rugged_repo.lookup(id)
        current_tree = current_tree.tree unless current_tree.is_a?(Rugged::Tree)
        @index.read_tree(current_tree)
        @current_tree = Gollum::Git::Tree.new(current_tree)
      end

      def current_tree
        @current_tree
      end

      private

      def get_parents(parents, head)
        if parents
          parents.map{|parent| parent.commit}
        elsif ref = @rugged_repo.references[head]
          ref = ref.target
          ref = ref.target if ref.respond_to?(:target)
          [ref]
        end
      end

      def update_treemap(path, data)
        # From RJGit::Plumbing::Index
        path = path[1..-1] if path[0] == ::File::SEPARATOR
        path = path.split(::File::SEPARATOR)
        last = path.pop

        current = @treemap

        path.each do |dir|
          current[dir] ||= {}
          node = current[dir]
          current = node
        end

        current[last] = data
        @treemap
      end

    end

    class Ref
      def initialize(ref)
        @ref = ref
      end

      def name
        @ref.name
      end

      def commit
        Gollum::Git::Commit.new(@ref.target)
      end

    end

    class Repo

      def initialize(path, options)
        begin
          @repo = Rugged::Repository.new(path, options)
        #rescue Grit::InvalidGitRepositoryError
         # raise Gollum::InvalidGitRepositoryError
        #rescue Grit::NoSuchPathError
         # raise Gollum::NoSuchPathError
        end
      end

      def self.init(path)
        Rugged::Repository.init_at(path, false)
        self.new(path, :is_bare => false)
      end

      def self.init_bare(path)
        Rugged::Repository.init_at(path, true)
        self.new(path, :is_bare => true)
      end

      def bare
        @repo.bare?
      end

      def config
        @repo.config
      end

      def git
        @git ||= Gollum::Git::Git.new(@repo)
      end

      def commit(id)
        git.commit_from_ref(id)
      end

      def commits(start = 'refs/heads/master', max_count = 10, skip = 0)
        git.log(start, nil, :max_count => max_count, :skip => skip)
      end

      def head
        Gollum::Git::Ref.new(@repo.head)
      end

      def index
        @index ||= Gollum::Git::Index.new(@repo.index, @repo)
      end

      def diff(sha1, sha2, *paths)
        opts = path == nil ? {} : {:path => path}
        patches = @repo.diff(sha1, sha2, opts).patches
        if not paths.empty?
          patches.keep_if { |p| paths.include? p.delta.new_file[:path] }
        end
        patches.map  {|patch| OpenStruct.new(:diff => patch.to_s.split("\n")[2..-1].join("\n").force_encoding("UTF-8"))}.reverse # First remove two superfluous lines. Rugged seems to order the diffs differently than Grit, so reverse.
      end

      def log(commit = 'refs/heads/master', path = nil, options = {})
        git.log(commit, path, options)
      end

      def lstree(sha, options = {})
        results = []
        @repo.lookup(sha).tree.walk(:postorder) do |root, entry|
          entry[:sha] = entry[:oid]
          entry[:mode] = entry[:filemode].to_s(8)
          entry[:type] = entry[:type].to_s
          entry[:path] = "#{root}#{entry[:name]}"
          results << entry
        end
        results
      end

      def path
        @repo.path
      end

      # Checkout branch and if necessary first create it. Currently used only in gollum-lib's tests.
      def update_ref(ref, commit_sha)
        ref = "refs/heads/#{ref}" unless ref =~ /^refs\/heads\//
        if _ref = @repo.references[ref]
          @repo.references.update(_ref, commit_sha)
        else
          @repo.create_branch(ref, commit_sha)
          @repo.checkout(ref, :strategy => :force) unless @repo.bare?
        end
      end
    end

    class Tree

      def initialize(tree)
        @tree = tree
      end

      def keys
        @tree.map{|entry| entry[:name]}
      end

      def [](i)
        @tree[i]
      end

      def id
        @tree.oid
      end

      def /(file)
        return self if file == '/'
        begin
        obj = @tree.path(file)
        rescue Rugged::TreeError
          return nil
        end
        return nil if obj.nil?
        obj = @tree.owner.lookup(obj[:oid])
        obj.is_a?(Rugged::Tree) ? Gollum::Git::Tree.new(obj) : Gollum::Git::Blob.new(obj)
      end

      def blobs
        blobs = []
        @tree.each_blob {|blob| blobs << Gollum::Git::Blob.new(@tree.owner.lookup(blob[:oid]), blob) }
        blobs
      end

    end

  end
end
