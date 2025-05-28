
Migration script steps
- [ ] Migrate Teams
- [ ] Migrate Area And Iterations
- [ ] Migrate Groups
- [ ] Migrate Test Variables
- [ ] Migrate Test Configurations
- [ ] Migrate Test Plans And Suites
- [ ] Migrate Work Item Querys
- [ ] Shared Queries
- [ ] Migrate Repos
- [ ] Migrate Wikis
- [ ] Migrate Task Groups
- [ ] Migrate Variable Groups
- [ ] Migrate Service Connections
- [ ] Migrate Build Queues (Agent Pools in UI)
- [ ] Migrate Build Pipelines
- [ ] Migrate Release Pipelines
- [ ] Migrate Service Hookss
- [ ] Migrate Policies
- [ ] Migrate Dashboards
- [ ] Migrate WorkItems
- [ ] Artifacts



Migration Step Order (Full Migration)
--------------------
- Build Queues (Project Agent Pools)
- Build Environments done with Build Queues
- Repositories
- Wikis
- Service Connections
- Areas and Iterations
- Teams
- Work Item Querys
- Variable Groups
- Build Pipelines
- Release Pipelines
- Task Groups
- Work Items
- Test Cases
- Groups and Teams
- Test Configurations
- Test Variables
- Test Plans, Suites, and Cases
- Service Hooks
- Policies
- Dashboards
- Delivery Plans 
- Artifacts

Partial Migrations Execution Order
--------------------
- Service Connections
- Areas and Iterations
- Teams
- Work Item Querys
- Variable Groups
- Build Pipelines & Task Groups
- Release Pipelines 
- Work-Items 
- Groups
- Test Configurations
- Test Variables
- Test Plans, Suites, and Cases
- Service Hooks
- Policies   (this will delete polices, then re-migrate them )
- Dashboards
- Delivery Plans
- Artifacts



