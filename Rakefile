require 'fileutils'
require 'yaml'
require 'shellwords'

module AT
  class DotfileSetupHandler
    def initialize(location:, verbose:, config_file:)
      @location = location
      @verbose = verbose
      @config = YAML.load_file(config_file)
      setup_default_shell
      sync_submodules
      setup_symlinks
      setup_vim
      install_homebrew_packages
      install_apps
      install_fonts
      setup_languages
      setup_launch_scripts
      other_config
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
          with_log("ln -s #{pwd}/#{filename} #{@location}/#{filename}")
        end
      end

      @config['custom_symlinks'].each do |source, destination|
        with_log("rm -rf #{destination}")
        with_log("ln -s #{pwd}/#{source} #{destination}")
      end

    end

    def setup_vim
      message "Setting up nvim..."
      with_log("mkdir -p #{@location}/.config/nvim")
      with_log("rm -rf #{@location}/.config/nvim/init.vim")
      with_log("ln -s #{pwd}/.init.vim #{@location}/.config/nvim/init.vim")

      message "Setting up vimplug..."
      with_log("curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim")
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

    def setup_languages
      @config['languages'].each do |language, config|
        message "Setting up #{language}..."

        with_log("asdf plugin-list | grep #{language}") ||
          with_log("asdf plugin-add #{language}") ||
          error("Unable to install #{language}")

        (config['versions'] || []).each do |version|
          with_log("asdf list #{language} | grep #{version}") ||
            with_log("NODEJS_CHECK_SIGNATURES=no asdf install #{language} #{version}") ||
            error("Unable to install #{language} #{version}")
        end

        (config['libs'] || []).each do |lib|
          with_log("#{config['install_command']} #{lib}") ||
            error("Unable to install #{lib}")
        end
      end
    end

    def install_fonts
      message "Installing powerline fonts"
      with_log("fonts/install.sh")
    end

    def setup_launch_scripts
      message "Setting up launch scripts..."
      Dir.foreach('./launch-scripts') do |filename|
        with_log("launchctl unload -w ./launch-scripts/#{filename}")
        with_log("launchctl load -w ./launch-scripts/#{filename}")
      end
    end

    def other_config
      message "Running other configuration scripts..."
      @config['other_config'].each do |command|
        with_log(command)
      end
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

    def pwd
      Shellwords.shellescape(Dir.pwd)
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
task :quiet, [:location] => :setup_configs
task :loud, [:location] do |t, args|
  Rake::Task[:default].invoke(args[:location], true)
end
