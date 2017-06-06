require 'fileutils'
require 'yaml'

module AT
  class DotfileSetupHandler
    def initialize(location:, verbose:, config_file:)
      @location = location
      @verbose = verbose
      @config = YAML.load_file(config_file)
      setup_default_shell
      sync_submodules
      setup_symlinks
      setup_nvim
      install_homebrew_packages
      install_apps
      install_language_versions
      install_libraries
      install_fonts
      message "All done!"
    end

    private

    def setup_default_shell
      message "Setting up default shell..."
      with_log("chsh -s $(which zsh)")
      with_log("curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh")
    end

    def sync_submodules
      message "Syncing submodules..."
      with_log("git submodule update --init")
      with_log("git submodule sync")
    end

    def setup_symlinks
      message "Setting up symlinks..."
      Dir.foreach('./') do |filename|
        if should_symlink?(filename)
          with_log("rm -rf #{@location}/#{filename}")
          with_log("ln -s #{Dir.pwd}/#{filename} #{@location}/#{filename}")
        end
      end
    end

    def setup_nvim
      message "Setting up nvim..."
      with_log("mkdir -p #{@location}/.config/nvim")
      with_log("rm -rf #{@location}/.config/nvim/init.vim")
      with_log("ln -s #{Dir.pwd}/.init.vim #{@location}/.config/nvim/init.vim")
    end

    def install_homebrew_packages
      if with_log("brew info")
        message "Installing homebrew packages..."
        with_log("brew update")
        with_log("brew upgrade")
        with_log("brew install #{@config['homebrew_packages'].join(' ')}")
        with_log("brew cleanup")
      else
        error "Unable to install dependencies with homebrew"
      end
    end

    def install_apps
      if with_log("brew cask help")
        message "Installing apps..."
        with_log("brew cask install #{@config['brew_cask_apps'].join(' ')} --force")
        with_log("brew cask cleanup")
      else
        error "Unable to install apps with brew cask"
      end
    end

    def install_language_versions
      message "Installing ruby #{ENV['RB_VERSION']}"
      with_log("ruby-install ruby #{ENV['RB_VERSION']} --no-reinstall") ||
        error("Unable to install ruby")

      node_version = "5.0"
      message "Installing node #{node_version}"
      with_log("nvm install #{node_version}") || error("Unable to install node")
    end

    def install_libraries
      @config['libraries'].each do |language, lib_def|
        message "Installing #{language} libraries..."
        lib_def['libs'].each do |l|
          with_log("#{lib_def['install_command']} #{l}") ||
            error("Unable to install #{l}")
        end
      end
    end

    def install_fonts
      message "Installing powerline fonts"
      with_log("fonts/install.sh")
    end

    def should_symlink?(filename)
      filename[0] == '.' && !@config['symlinks_to_skip'].include?(filename)
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

    def with_log(command)
      if @verbose
        system("#{command}")
      else
        system("#{command} >> /dev/null 2>&1")
      end
    end
  end
end


task :setup_configs, [:location, :verbose, :config_file] do |t, args|
  args.with_defaults(location: "$HOME", verbose: false, config_file: "install.yml")
  AT::DotfileSetupHandler.new(args)
end

task :default, [:location, :verbose, :config_file] => :setup_configs
task :quiet,   [:location]           => :setup_configs
task :loud,    [:location]           { |t, args| Rake::Task[:default].invoke(args[:location], true) }
