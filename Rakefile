require 'fileutils'

module AT
  class DotfileSetupHandler
    FILES_TO_SKIP = [".","..",".git",".gitignore",".ruby-version"]
    FILES_TO_INCLUDE = ['tmux-helpers', '.vim']

    DEPENDENCIES = ["autojump","bash-completion","ctags","git","macvim",
                    "rbenv","rbenv-gem-rehash","reattach-to-user-namespace",
                    "ruby-build","tmux","wemux"]

    GEMS = ["tmuxinator","rcodetools","hub","git-branch-delete-orphans"]

    RB_VERSION = "2.1.5"

    attr_accessor :location

    def self.setup_dotfiles
      new("$HOME")
    end

    def initialize(location)
      self.location = location
      setup_symlinks
      source_bash_profile
      install_system_dependencies
      install_ruby unless ENV['SKIP_RUBY']
      install_gems
      install_pygments
      setup_vim
      message "All done!"
    end

    private

    def setup_symlinks
      message "Setting up symlinks..."
      Dir.foreach('./') do |filename|
        if should_symlink?(filename)
          silent_system("rm -rf #{location}/#{filename}")
          silent_system("ln -s #{Dir.pwd}/#{filename} #{location}/#{filename}")
        end
      end
    end

    def source_bash_profile
      message "Loading configs..."
      silent_system("source #{location}/.bash_profile")
    end

    def install_system_dependencies
      if silent_system("brew info")
        message "Installing system dependencies..."
        silent_system("brew install #{DEPENDENCIES.join(" ")}")
      else
        error "Unable to install dependencies with homebrew, please install #{DEPENDENCIES}"
      end
    end

    def install_ruby
      message "Installing ruby #{RB_VERSION}"
      silent_system("rbenv install #{RB_VERSION}") || error("Unable to install ruby")
    end

    def install_gems
      message "Installing gem dependencies..."
      GEMS.each do |g|
        silent_system("gem install #{g}") ||
          error("Unable to install #{g}")
      end
    end

    def install_pygments
      message "Installing Pygments (for syntax-highlighted cat)"
      silent_system("sudo easy_install Pygments") || error("Unable to install Pygments")
    end

    def setup_vim
      message "Setting up vim..."
      silent_system("cd .vim && rm -rf vundle && git clone http://github.com/gmarik/vundle.git")
      action "Make sure to run :BundleInstall the first time you open up vim!"
    end

    def should_symlink?(filename)
      FILES_TO_INCLUDE.include?(filename) ||
        (filename[0] == '.' && !FILES_TO_SKIP.include?(filename))
    end

    def message(str)
      puts "\e[32m#{str}\e[0m"
    end

    def error(str)
      puts "\e[31m#{str}\e[0m"
    end

    def action(str)
      puts "\e[33m#{str}\e[0m"
    end

    def silent_system(command)
      system("#{command} >> /dev/null 2>&1")
    end
  end
end

desc "Symlinks relevant configs"
task :default do
  AT::DotfileSetupHandler.setup_dotfiles
end
