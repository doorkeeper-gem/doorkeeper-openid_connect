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
      attr_reader :size
      attr_reader :id

      def self.create(repo, options)
        blob = repo.git.lookup(options[:id])
        self.new(blob, options)
      end
      
      def initialize(blob, options = {})
        @blob = blob
        @mode = options[:filemode]
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

      def symlink_target(base_path = nil)
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
        @commit.time
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
        diff = @commit.diff.each_patch do |patch|
          new_additions = patch.stat[0]
          new_deletions = patch.stat[1]
          additions += new_additions
          deletions += new_deletions
          total += patch.changes
          files << [patch.delta.new_file[:path], new_deletions, new_additions, patch.changes] # Rugged seems to generate the stat diffs in the other direciton than grit does by default, so switch the order of additions and deletions.
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
        ::File.exists?(repo.path)
      end
      
      def grep(query, options={})
        ref = options[:ref] ? options[:ref] : "HEAD"
        result = [] # implement grep here
        result.map do |line|
          branch_and_name, _, count = line.rpartition(":")
          branch, _, name = branch_and_name.partition(':')
          {:name => name, :count => count}
        end
      end
      
      def rm(path, options = {})
        index = @repo.index
        index.write
        File.unlink File.join(repo.workdir, path)
      end

      def cat_file(options, sha)
        @repo.lookup(sha).read_raw
      end

      def apply_patch(head_sha = 'HEAD', patch=nil)
        true # Rewrite gollum-lib's revert so that it doesn't require a direct equivalent of Grit's apply_patch
      end
      
      def checkout(path, ref = 'HEAD', options = {})
        path = path.nil? ? path : [path]
        options = options.merge({:paths => path, :strategy => :safe_create})
        if ref == 'HEAD'
          @repo.checkout_head(options)
        else
          ref = "refs/heads/#{ref}" unless ref =~ /^refs\/heads\//
          @repo.checkout_tree(sha_from_ref(ref), options)
        end
      end

      def log(commit = 'refs/heads/master', path = nil, options = {})
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
        sha = sha_from_ref(commit)
        begin
          build_log(sha, options)
        rescue Rugged::OdbError, Rugged::InvalidError, Rugged::ReferenceError
        # Return an empty array if the ref wasn't found
          []
        end
      end

      def versions_for_path(path = nil, ref = nil, options = nil)
        options.delete :max_count
        options.delete :skip
        log(path, ref, options)
      end
      
      def ls_files(query, options = {})
        ref = "refs/heads/#{ref}" if options[:ref] && !(ref =~ /^refs\/heads\//)
        ref = "HEAD" if ref.nil?
        match = query.match(/^(\*)(.*)(\*)$/)
        query = match.nil? ? query : match[2]
        results = []
        commit = @repo.references[ref].target
        commit = commit.is_a?(Rugged::Reference) ? commit.target.tree : commit.tree
        commit.walk_blobs do |root, blob|
          results << "#{root}#{blob[:name]}" if blob[:name] =~ /#{query}/
        end
        results
      end

      def lookup(id)
        @repo.lookup(id)
      end

      def sha_from_ref(ref)
        sha = @repo.rev_parse_oid(ref)
        object = @repo.lookup(sha)
        if object.kind_of?(Rugged::Commit)
        sha
        elsif object.respond_to?(:target)
        sha_from_ref(object.target.oid)
        end
      end

      private

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
        parents.map!{|parent| parent.commit} if parents
        parents = [@rugged_repo.references[head].target].compact unless parents
        parents = [] unless parents
        commit_options[:tree] = @index.write_tree
        commit_options[:author] = actor.to_h
        commit_options[:message] = message
        commit_options[:parents] = parents
        commit_options[:update_ref] = head
        Rugged::Commit.create(@rugged_repo, commit_options)
      end
      
      def tree
        @treemap
      end
      
      def read_tree(id)
        current_tree = @rugged_repo.lookup(id)
        current_tree = current_tree.tree unless current_tree.is_a?(Rugged::Tree)
        @index.read_tree(current_tree)
        @current_tree = Gollum::Git::Tree.new(current_tree)
      end
      
      def current_tree
        @current_tree
      end

      private

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
        Rugged::Repopository.init_at(path, false)
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
        begin
          sha = git.sha_from_ref(id)
          commit = @repo.lookup(sha)
        rescue Rugged::ReferenceError
           return nil
        end
        return nil if commit.nil?
        Gollum::Git::Commit.new(commit)
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

      def diff(sha1, sha2, path = nil)
        opts = path == nil ? {} : {:path => path}
        @repo.diff(sha1, sha2, opts)
      end
      
      def log(commit = 'refs/heads/master', path = nil, options = {})
        git.log(commit, path, options)
      end
      
      def lstree(sha, options = {})
        results = []
        @repo.lookup(sha).tree.walk(:postorder) do |root, entry|
          entry[:sha] =  entry[:oid]
          results << entry
        end
        results
      end
      
      def path
        @repo.path
      end
      
      def update_ref(ref, commit_sha)
        @repo.references(ref).set_target(commit_sha)
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
        @tree.path(file) 
      end
      
      def blobs
        blobs = []
        @tree.each_blob {|blob| blobs << Gollum::Git::Blob.new(@tree.owner.lookup(blob[:oid]), blob) }
        blobs
      end
    end
    
  end
end