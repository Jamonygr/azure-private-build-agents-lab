# Lab profile

Load `lab.tfvars` before your ignored `.local/lab.tfvars`. Later arguments override earlier ones. The default lab uses one stateless Windows agent, no standby, and Azure Firewall Standard. Firewall billing continues while agents are idle. Region and address-space overrides are explicit; the scripts never choose a fallback region.

Each lab identifier has independent local foundation state and a separate private workload state key. Do not point a new lab identifier at another lab's state.
