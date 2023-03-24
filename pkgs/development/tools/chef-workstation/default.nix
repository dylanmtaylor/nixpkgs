{ lib, bundlerEnv, bundlerUpdateScript, ruby, perl, autoconf }:

bundlerEnv {
  name = "chef-workstation-23.3.1031";
  # Do not change this to pname & version until underlying issues with Ruby
  # packaging are resolved ; see https://github.com/NixOS/nixpkgs/issues/70171

  inherit ruby;
  gemdir = ./.;

  buildInputs = [ perl autoconf ];

  passthru.updateScript = bundlerUpdateScript "chef-workstation";

  meta = with lib; {
    description = "Chef Workstation gives you everything you need to get started with Chef, so you can automate how you audit, configure, and manage applications end environments.";
    homepage    = "https://docs.chef.io/workstation/";
    license     = licenses.asl20;
    maintainers = with maintainers; [ dylanmtaylor ];
    platforms   = platforms.unix;
  };
}
