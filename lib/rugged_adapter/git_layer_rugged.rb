# ~*~ encoding: utf-8 ~*~

require 'rugged'

module Gollum

  def self.set_git_timeout(time)
  end

  def self.set_git_max_filesize(size)
  end

  module Git
    
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
      end
      
      def checkout(path, ref, options = {})
        if ref == 'HEAD'
          @repo.checkout_head(:paths => [path])
        elsif path == 'nil'
          @repo.checkout(ref)
        else
          raise "Rugged cannot checkout specific paths for a ref other than HEAD."
        end
      end

      def lookup(sha)
        @repo.lookup(sha)
      end
      
      def ls_files(query, options = {})
        ref = options[:ref] ? options[:ref] : "HEAD"
        # implement ls_files
      end
      
      def apply_patch(sha, patch)
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
        blob = @rugged_repo.write("data", :blob)
        @index.add(:path => path, :oid => blob, :mode => 0100644)
        update_treemap(path, data)
        data
      end
      
      def commit(message, parents = nil, actor = nil, last_tree = nil, head = 'master')
        # @index.commit(message, parents, actor, last_tree, head)
        # rugged index does not have commit method
      end
      
      def tree
        puts "TREEMAP: #{@treemap}"
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
        path_parts = path.split(::File::SEPARATOR)
          i = 0
          @treemap = path_parts.inject(@treemap) do |map, path_element|
            i = i + 1
            map[path_element] = i == path_parts.size ? data : Hash.new if (map[path_element] == nil || data == false)
            map
          end
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
        Grit::Repo.init_bare(path, true)
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
        commit = @repo.lookup(id)
        return nil if commit.nil?
        Gollum::Git::Commit.new(commit)
      end
      
      def commits(start = 'refs/heads/master', max_count = 10, skip = 0)
        walker = Rugged::Walker.new(@repo)
        sha = @repo.references[start].target_id
        walker.push(sha)
        commits = []
        walker.each do |commit|
          next if commits.size > max_count
          commits << Gollum::Git::Commit.new(commit)
        end
        commits
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
      
      def log(commit = 'master', path = nil, options = {})
        default_options = {
          :limit => 10,
          :offset => 0,
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
      
      def lstree(sha, options = {})
      end
      
      def path
        @repo.path
      end
      
      def update_ref(ref, commit_sha)
        @repo.references(ref).set_target(commit_sha)
      end

      private

      def sha_from_ref(ref)
        sha = @repo.rev_parse_oid(ref)
        object = @repo.lookup(sha)
        if object.kind_of?(Rugged::Commit)
        sha
        elsif object.respond_to?(:target)
        sha_from_ref(object.target.oid)
        end
      end


      # Return an array of log commits, given an SHA hash and a hash of
      # options.
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