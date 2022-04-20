{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.home-manager;

  extendedLib = import ../modules/lib/stdlib-extended.nix pkgs.lib;

  hmModule = types.submoduleWith {
    specialArgs = {
      lib = extendedLib;
      darwinConfig = config;
      osConfig = config;
      modulesPath = builtins.toString ../modules;
    } // cfg.extraSpecialArgs;
    modules = [
      ({ name, ... }: {
        imports = import ../modules/modules.nix {
          inherit pkgs;
          lib = extendedLib;
          useNixpkgsModule = !cfg.useGlobalPkgs;
        };

        config = {
          submoduleSupport.enable = true;
          submoduleSupport.externalPackageInstall = cfg.useUserPackages;

          home.username = config.users.users.${name}.name;
          home.homeDirectory = config.users.users.${name}.home;

          # Make activation script use same version of Nix as system as a whole.
          # This avoids problems with Nix not being in PATH.
          home.extraActivationPath = [ config.nix.package ];
        };
      })
    ] ++ cfg.sharedModules;
  };

in

{
  options = {
    home-manager = {
      useUserPackages = mkEnableOption ''
        installation of user packages through the
        <option>users.users.&lt;name?&gt;.packages</option> option.
      '';

      useGlobalPkgs = mkEnableOption ''
        using the system configuration's <literal>pkgs</literal>
        argument in Home Manager. This disables the Home Manager
        options <option>nixpkgs.*</option>
      '';

      backupFileExtension = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "backup";
        description = ''
          On activation move existing files by appending the given
          file extension rather than exiting with an error.
        '';
      };

      extraSpecialArgs = mkOption {
        type = types.attrs;
        default = { };
        example = literalExpression "{ inherit emacs-overlay; }";
        description = ''
          Extra <literal>specialArgs</literal> passed to Home Manager. This
          option can be used to pass additional arguments to all modules.
        '';
      };

      sharedModules = mkOption {
        type = with types;
          # TODO: use types.raw once this PR is merged: https://github.com/NixOS/nixpkgs/pull/132448
          listOf (mkOptionType {
            name = "submodule";
            inherit (submodule { }) check;
            merge = lib.options.mergeOneOption;
            description = "Home Manager modules";
          });
        default = [ ];
        example = literalExpression "[ { home.packages = [ nixpkgs-fmt ]; } ]";
        description = ''
          Extra modules added to all users.
        '';
      };

      verbose = mkEnableOption "verbose output on activation";

      users = mkOption {
        type = types.attrsOf hmModule;
        default = {};
        # Set as not visible to prevent the entire submodule being included in
        # the documentation.
        visible = false;
        description = ''
          Per-user Home Manager configuration.
        '';
      };
    };
  };

  config = mkIf (cfg.users != {}) {
    warnings =
      flatten (flip mapAttrsToList cfg.users (user: config:
        flip map config.warnings (warning:
          "${user} profile: ${warning}"
        )
      ));

    assertions =
      flatten (flip mapAttrsToList cfg.users (user: config:
        flip map config.assertions (assertion:
          {
            inherit (assertion) assertion;
            message = "${user} profile: ${assertion.message}";
          }
        )
      ));

    users.users = mkIf cfg.useUserPackages (
      mapAttrs (username: usercfg: {
        packages = [ usercfg.home.path ];

        launchd.agents."home-manager-${username}" = let
          # hmSetupEnv = pkgs.writeScript "hm-setup-env" ''
          #   echo Activating home-manager configuration for ${username}
          #   sudo -u ${username} -s --set-home ${pkgs.writeShellScript "activation-${username}" ''
          #     ${lib.optionalString (cfg.backupFileExtension != null)
          #       "export HOME_MANAGER_BACKUP_EXT=${lib.escapeShellArg cfg.backupFileExtension}"}
          #     ${lib.optionalString cfg.verbose "export VERBOSE=1"}
          #     exec ${usercfg.home.activationPackage}/activate
          #   ''}
          # '';
        in { # TODO(ryantking): probably should esca
          enable = true;
          config = {
            ProcessType = "Adaptive";
            # ProgramArguments = [ "${hmSetupEnv}" ];
          };
        };
      }) cfg.users
    );

    environment.pathsToLink = mkIf cfg.useUserPackages [ "/etc/profile.d" ];

    # launchd.agents = mapAttrs' (_: usercfg:
    #   let
    #     username = usercfg.home.username;

    #     hmSetupEnv = pkgs.writeScript "hm-setup-env" ''
    #       echo Activating home-manager configuration for ${username}
    #       sudo -u ${username} -s --set-home ${pkgs.writeShellScript "activation-${username}" ''
    #         ${lib.optionalString (cfg.backupFileExtension != null)
    #           "export HOME_MANAGER_BACKUP_EXT=${lib.escapeShellArg cfg.backupFileExtension}"}
    #         ${lib.optionalString cfg.verbose "export VERBOSE=1"}
    #         exec ${usercfg.home.activationPackage}/activate
    #       ''}
    #     '';
    #   in nameValuePair ("home-manager-${username}") { # TODO(ryantking): probably should esca
    #     enable = true;
    #     config = {
    #       ProcessType = "Adaptive";
    #       ProgramArguments = [ "${hmSetupEnv}" ];
    #     };
    #   }) cfg.users;
  };
}
