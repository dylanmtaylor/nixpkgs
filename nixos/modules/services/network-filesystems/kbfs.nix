{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.security) wrapperDir;
  cfg = config.services.kbfs;

in
{

  ###### interface

  options = {

    services.kbfs = {

      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to mount the Keybase filesystem.";
      };

      enableRedirector = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable the Keybase root redirector service, allowing
          any user to access KBFS files via `/keybase`,
          which will show different contents depending on the requester.
        '';
      };

      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "%h/keybase";
        example = "/keybase";
        description = "Mountpoint for the Keybase filesystem.";
      };

      extraFlags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "-label kbfs"
          "-mount-type normal"
        ];
        description = ''
          Additional flags to pass to the Keybase filesystem on launch.
        '';
      };

    };
  };

  ###### implementation

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # Upstream: https://github.com/keybase/client/blob/master/packaging/linux/systemd/kbfs.service
        systemd.user.services.kbfs = {
          description = "Keybase File System";

          # Note that the "Requires" directive will cause a unit to be restarted whenever its dependency is restarted.
          # Do not issue a hard dependency on keybase, because kbfs can reconnect to a restarted service.
          # Do not issue a hard dependency on keybase-redirector, because it's ok if it fails (e.g., if it is disabled).
          wants = [ "keybase.service" ] ++ lib.optional cfg.enableRedirector "keybase-redirector.service";
          path = [ "/run/wrappers" ];
          unitConfig.ConditionUser = "!@system";

          serviceConfig = {
            Type = "notify";
            # Keybase notifies from a forked process
            EnvironmentFile = [
              "-%E/keybase/keybase.autogen.env"
              "-%E/keybase/keybase.env"
            ];
            ExecStartPre = [
              "${pkgs.coreutils}/bin/mkdir -p \"${cfg.mountPoint}\""
              "-${wrapperDir}/fusermount -uz \"${cfg.mountPoint}\""
            ];
            ExecStart = "${pkgs.kbfs}/bin/kbfsfuse ${toString cfg.extraFlags} \"${cfg.mountPoint}\"";
            ExecStop = "${wrapperDir}/fusermount -uz \"${cfg.mountPoint}\"";
            Restart = "on-failure";
            PrivateTmp = true;
          };
          wantedBy = [ "default.target" ];
        };

        services.keybase.enable = true;

        environment.systemPackages = [ pkgs.kbfs ];
      }

      (lib.mkIf cfg.enableRedirector {
        security.wrappers."keybase-redirector".source = "${pkgs.kbfs}/bin/redirector";

        systemd.tmpfiles.settings."10-kbfs"."/keybase".d = {
          user = "root";
          group = "root";
          mode = "0755";
          age = "0";
        };

        # Upstream: https://github.com/keybase/client/blob/master/packaging/linux/systemd/keybase-redirector.service
        systemd.user.services.keybase-redirector = {
          description = "Keybase Root Redirector for KBFS";
          wants = [ "keybase.service" ];
          unitConfig.ConditionUser = "!@system";

          serviceConfig = {
            EnvironmentFile = [
              "-%E/keybase/keybase.autogen.env"
              "-%E/keybase/keybase.env"
            ];
            # Note: The /keybase mount point is not currently configurable upstream.
            ExecStart = "${wrapperDir}/keybase-redirector /keybase";
            Restart = "on-failure";
            PrivateTmp = true;
          };

          wantedBy = [ "default.target" ];
        };
      })
    ]
  );
}
