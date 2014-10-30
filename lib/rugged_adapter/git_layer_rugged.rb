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

      def self.create(repo, options)
        blob = repo.lookup(options[:id])
        self.new(blob, options)
      end
      
      def initialize(blob, options = {})
        @blob = blob
        @mode = options[:mode]
        @name = options[:name]
      end
      
      def id
        @blob.oid
      end
      
      def size
        @blob.size
      end
      
      def data
        @blob.content
      end
      
      def mime_type
        @blob.mime_type
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
        @author_info ||= commit.author
        Gollum::Git::Actor.new(@author_info[:name], @author_info[:email])
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
      
      
      def ls_files(query, options = {})
        ref = options[:ref] ? options[:ref] : "HEAD"
        # implement ls_files
      end
      
      def apply_patch(sha, patch)
      end

      def log(path = nil, ref = nil, options = nil)
      end

      def repo
        Repo.new(@repo)
      end
      
    end
    
    class Index
      
      def initialize(index, repo)
        @index = index
        @rugged_repo = repo
        @current_tree = nil
      end
      
      def delete(path)
        @index.remove_all(path)
      end
      
      def add(path, data)
        @index.add(path, data)
      end
      
      def commit(message, parents = nil, actor = nil, last_tree = nil, head = 'master')
        # @index.commit(message, parents, actor, last_tree, head)
        # rugged index does not have commit method
      end
      
      def tree
        #make grit-style treemap from index
      end
      
      def read_tree(id)
        current_tree = @rugged_repo.lookup(id)
        #@index.read_tree(current_tree)
        @current_tree = Gollum::Git::Tree.new(current_tree)
      end
      
      def current_tree
        @current_tree
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
      
      # @wiki.repo.head.commit.sha
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
      end
      
      def lstree(sha, options = {})
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
        @tree.each_blob {|blob| blobs << Gollum::Git::Blob.new(blob) }
        blobs
      end
    end
    
  end
end