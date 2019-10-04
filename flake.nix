{
  edition = 201909;

  inputs.nixpkgs.uri = "nixpkgs/release-19.03";
  inputs.hydra.uri = "/home/eelco/Dev/hydra";

  outputs = { self, nixpkgs, hydra }:

    let
      region = "eu-west-1";
      zone = "eu-west-1a";
    in

    {

      nixopsConfigurations.default = {

        inherit nixpkgs;

        hydra-server =
          { config, pkgs, resources, ... }:
          { system.configurationRevision = self.rev;

            deployment.targetEnv = "ec2";
            deployment.ec2.region = region;
            deployment.ec2.zone = zone;
            deployment.ec2.instanceType = "t3.medium";
            deployment.ec2.keyPair = resources.ec2KeyPairs.hydra-key;
            deployment.ec2.securityGroups = [];
            deployment.ec2.securityGroupIds = [ resources.ec2SecurityGroups.hydra-sg.name ];
            deployment.ec2.subnetId = resources.vpcSubnets.hydra-subnet;
            deployment.ec2.associatePublicIpAddress = true;
            deployment.ec2.ebsInitialRootDiskSize = 50;

            imports =
              [ hydra.nixosModules.hydraTest
                hydra.nixosModules.hydraProxy
              ];

            services.hydra-dev.useSubstitutes = true;

            networking.firewall.allowedTCPPorts = [ 80 ];

            swapDevices = [ { device = "/swapfile"; size = 4096; } ];
          };

        resources.vpc.hydra-vpc =
          {
            inherit region;
            instanceTenancy = "default";
            enableDnsSupport = true;
            enableDnsHostnames = true;
            cidrBlock = "10.0.0.0/16";
          };

        resources.vpcSubnets.hydra-subnet =
          { resources, lib, ... }:
          {
            inherit region zone;
            vpcId = resources.vpc.hydra-vpc;
            cidrBlock = "10.0.0.0/19";
            mapPublicIpOnLaunch = true;
            tags.Source = "NixOps";
          };

        resources.ec2SecurityGroups.hydra-sg =
          { resources, lib, ... }:
          {
            inherit region;
            vpcId = resources.vpc.hydra-vpc;
            rules = [
              { toPort = 22; fromPort = 22; sourceIp = "0.0.0.0/0"; }
              { toPort = 80; fromPort = 80; sourceIp = "0.0.0.0/0"; }
            ];
          };

        resources.vpcRouteTables.hydra-route-table =
          { resources, ... }:
          {
            inherit region;
            vpcId = resources.vpc.hydra-vpc;
          };

        resources.vpcRouteTableAssociations.hydra-assoc =
          { resources, ... }:
          {
            inherit region;
            subnetId = resources.vpcSubnets.hydra-subnet;
            routeTableId = resources.vpcRouteTables.hydra-route-table;
          };

        resources.vpcInternetGateways.hydra-igw =
          { resources, ... }:
          {
            inherit region;
            vpcId = resources.vpc.hydra-vpc;
          };

        resources.vpcRoutes.hydra-route =
          { resources, ... }:
          {
            inherit region;
            routeTableId = resources.vpcRouteTables.hydra-route-table;
            destinationCidrBlock = "0.0.0.0/0";
            gatewayId = resources.vpcInternetGateways.hydra-igw;
          };

        resources.ec2KeyPairs.hydra-key =
          { inherit region;
          };

      };

    };
}
