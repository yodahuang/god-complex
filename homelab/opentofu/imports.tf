# These objects predate OpenTofu management. The import blocks seed the local
# state on the first apply; once each address is in state, they are inert.
import {
  to = cloudflare_dns_record.public_wildcard
  id = "f7fcc64c886b226cb50b22f62765c64f/42e612ae51fdb77eacd9430e85d982da"
}

import {
  to = unifi_client.reservation["earl_grey"]
  id = "e4:5f:01:67:99:1c"
}

import {
  to = unifi_client.reservation["nas"]
  id = "00:11:32:de:0e:bd"
}

import {
  to = unifi_client.reservation["rig"]
  id = "04:d9:f5:f4:e6:f1"
}
