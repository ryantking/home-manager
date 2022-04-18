{ config, extendModules, lib, ... }:

with lib;

{
  options.specialization = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        configuration = mkOption {
          type = let
            stopRecursion = { specialization = mkOverride 0 { }; };
            extended = extendModules { modules = [ stopRecursion ]; };
          in extended.type;
          default = { };
          visible = "shallow";
          description = ''
            Arbitrary Home Manager configuration options.
          '';
        };

        # TODO:
        # inheritParentConfig = mkOption {
        #   type = types.bool;
        #   default = true;
        #   description = ''
        #   Whether to base the configuration on the overall configuration. When
        #   <literal>false</literal> the specialization is an entirely
        #   standalone configuration.
        # '';
        # };
      };
    });
    default = { };
    description = ''
      A set of specialized configurations.
    '';
  };

  config = mkIf (config.specialization != { }) {
    home.extraBuilderCommands = let
      link = n: v:
        let pkg = v.configuration.home.activationPackage;
        in "ln -s ${pkg} $out/specialization/${n}";
    in ''
      mkdir $out/specialization
      ${concatStringsSep "\n" (mapAttrsToList link config.specialization)}
    '';
  };
}
