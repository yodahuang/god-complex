{lib}: let
  inherit (builtins) elemAt length match toString;

  duplicateValues = values: let
    uniqueValues = lib.unique values;
  in
    lib.filter (value: length (lib.filter (candidate: candidate == value) values) > 1) uniqueValues;

  validIPv4 = value: let
    parts = match "^([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})$" value;
  in
    parts
    != null
    && lib.all (part: let octet = lib.toInt part; in octet >= 0 && octet <= 255) parts;

  validMac = value:
    value
    == null
    || match "^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$" value != null;

  valid24Network = value: let
    parts = match "^([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.0/24$" value;
  in
    parts
    != null
    && lib.all (part: let octet = lib.toInt part; in octet >= 0 && octet <= 255) parts;

  same24Network = ip: cidr: let
    ipParts = match "^([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})$" ip;
    networkParts = match "^([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.0/24$" cidr;
  in
    ipParts
    != null
    && networkParts != null
    && elemAt ipParts 0 == elemAt networkParts 0
    && elemAt ipParts 1 == elemAt networkParts 1
    && elemAt ipParts 2 == elemAt networkParts 2;

  serviceById = inventory:
    lib.listToAttrs (map (service: {
        name = service.id;
        value = service;
      })
      inventory.services);

  serviceUrl = inventory: service: "https://${service.id}.${inventory.meta.publicDomain}";

  caddyHostnames = inventory: service: "http://${service.id}.${inventory.meta.localDomain}, ${service.id}.${inventory.meta.publicDomain}";

  backendTarget = inventory: service:
    if service.node == inventory.meta.ingressNode
    then "127.0.0.1"
    else inventory.nodes.${service.node}.lan.desiredIPv4;

  localDnsRecords = inventory: [
    {
      hostname = "*.${inventory.meta.publicDomain}";
      type = "A";
      targetNode = inventory.meta.ingressNode;
    }
  ];

  publicDnsIntent = inventory: [
    {
      hostname = "*.${inventory.meta.publicDomain}";
      type = "A";
      addressSource = "tailscale";
      targetNode = inventory.meta.ingressNode;
    }
  ];

  dashboardItem = inventory: service: let
    dashboard = service.dashboard;
  in
    {
      name = service.name;
      url = serviceUrl inventory service;
    }
    // lib.optionalAttrs (dashboard ? logo) {logo = dashboard.logo;}
    // lib.optionalAttrs (dashboard ? icon) {icon = dashboard.icon;}
    // lib.optionalAttrs (dashboard ? subtitle) {subtitle = dashboard.subtitle;};

  validate = inventory: let
    nodeIds = lib.attrNames inventory.nodes;
    serviceIds = map (service: service.id) inventory.services;
    nodeIps = map (nodeId: inventory.nodes.${nodeId}.lan.desiredIPv4) nodeIds;
    nodeMacs = lib.filter (mac: mac != null) (map (nodeId: inventory.nodes.${nodeId}.lan.reservationMac) nodeIds);
    ingressNode = inventory.nodes.${inventory.meta.ingressNode} or null;
    serviceMap = serviceById inventory;
    networkIds = lib.attrNames inventory.networks;
    dashboardCategories = inventory.dashboard.categories;

    nodeErrors = lib.concatLists (map (
        nodeId: let
          node = inventory.nodes.${nodeId};
          networkName = node.lan.network;
          network = inventory.networks.${networkName} or null;
        in
          (lib.optional (network == null) "node '${nodeId}' references unknown network '${networkName}'")
          ++ (lib.optional (!validIPv4 node.lan.desiredIPv4) "node '${nodeId}' has invalid LAN IPv4 '${node.lan.desiredIPv4}'")
          ++ (lib.optional (network != null && !same24Network node.lan.desiredIPv4 network.cidr) "node '${nodeId}' is outside network '${networkName}' (${network.cidr})")
          ++ (lib.optional (!validMac node.lan.reservationMac) "node '${nodeId}' has invalid reservation MAC '${toString node.lan.reservationMac}'")
          ++ (lib.optional (node.tailscale.enabled && !(node.tailscale ? selector)) "Tailscale-enabled node '${nodeId}' is missing a selector")
      )
      nodeIds);

    serviceErrors = lib.concatLists (map (
        service:
          (lib.optional (service.node or null == null || !(builtins.hasAttr service.node inventory.nodes)) "service '${service.id}' references unknown node '${toString (service.node or null)}'")
          ++ (lib.optional (service.caddy.kind == "reverseProxy" && (service.port or null) == null) "reverse-proxy service '${service.id}' is missing a port")
          ++ (lib.optional (service.caddy.kind == "reverseProxy" && ((service.port < 1) || (service.port > 65535))) "service '${service.id}' has an invalid port")
      )
      inventory.services);

    dashboardErrors = lib.concatLists (map (
        category:
          lib.concatLists (map (
              serviceId: let
                service = serviceMap.${serviceId} or null;
              in
                (lib.optional (service == null) "dashboard category '${category.name}' references unknown service '${serviceId}'")
                ++ (lib.optional (service != null && !(service ? dashboard)) "dashboard service '${serviceId}' has no dashboard metadata")
                ++ (lib.optional (service != null && service.dashboard.category != category.name) "service '${serviceId}' is assigned to '${service.dashboard.category}', not '${category.name}'")
            )
            category.serviceIds)
      )
      dashboardCategories);

    duplicateErrors =
      (lib.optional (duplicateValues serviceIds != []) "duplicate service IDs: ${lib.concatStringsSep ", " (duplicateValues serviceIds)}")
      ++ (lib.optional (duplicateValues nodeIps != []) "duplicate desired LAN IPv4s: ${lib.concatStringsSep ", " (duplicateValues nodeIps)}")
      ++ (lib.optional (duplicateValues nodeMacs != []) "duplicate reservation MACs: ${lib.concatStringsSep ", " (duplicateValues nodeMacs)}")
      ++ (lib.optional (duplicateValues (map (service: serviceUrl inventory service) inventory.services) != []) "duplicate service URLs");

    errors =
      (lib.optional (!(builtins.hasAttr inventory.meta.ingressNode inventory.nodes)) "ingress node '${inventory.meta.ingressNode}' does not exist")
      ++ (lib.optional (ingressNode != null && ingressNode.lan.reservationMac == null) "ingress node '${inventory.meta.ingressNode}' must have a reservation MAC")
      ++ (lib.optional (match "^[a-z0-9.-]+$" inventory.meta.localDomain == null) "invalid local domain '${inventory.meta.localDomain}'")
      ++ (lib.optional (match "^[a-z0-9.-]+$" inventory.meta.publicDomain == null) "invalid public domain '${inventory.meta.publicDomain}'")
      ++ (lib.concatLists (map (
          networkId:
            lib.optional (!valid24Network inventory.networks.${networkId}.cidr) "network '${networkId}' must use a valid /24 CIDR"
        )
        networkIds))
      ++ nodeErrors
      ++ serviceErrors
      ++ dashboardErrors
      ++ duplicateErrors;
  in
    if errors == []
    then inventory
    else throw "Invalid homelab inventory:\n${lib.concatStringsSep "\n" (map (error: "- ${error}") errors)}";

  manifest = inventory: {
    version = 1;
    meta = inventory.meta;
    networks = inventory.networks;
    dns = {
      local = localDnsRecords inventory;
      public = publicDnsIntent inventory;
    };
    nodes =
      lib.mapAttrsToList (id: node: {
        inherit id;
        displayName = node.displayName;
        lan = node.lan;
        tailscale = {
          enabled = node.tailscale.enabled;
          selector = node.tailscale.selector or null;
        };
      })
      inventory.nodes;
    services =
      map (service: {
        inherit (service) id name node caddy;
        port = service.port or null;
        url = serviceUrl inventory service;
        hostnames = caddyHostnames inventory service;
        backend =
          if service.caddy.kind == "reverseProxy"
          then {
            target = backendTarget inventory service;
            inherit (service) port;
          }
          else null;
      })
      inventory.services;
  };
in {
  inherit backendTarget caddyHostnames dashboardItem localDnsRecords manifest publicDnsIntent serviceById serviceUrl validate;
}
