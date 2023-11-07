OData can be use report on data from Azure DevOps Service and Server. See [Extend Analytics with OData](https://docs.microsoft.com/en-us/azure/devops/report/extend-analytics/quick-ref?view=azure-devops) for documentation on using OData.

Several OData views have been created that will report on data from Azure DevOps Server. See below for instructions on formatting OData queries to execute an on premise Azure DevOps Server.

## Azure DevOps Server URL formatting
all the samples in the Azure DevOps online docs site 
The organization url for Azure DevOps Server

The following query, which returns all work items in an organzation, is formatted to run against an Azure DevOps Server.

```
https://analytics.dev.azure.com/<organization>/_odata/v3.0-preview/WorkItems?
  $select=WorkItemId,ProjectSK,Title,WorkItemType,State,CreatedDate,ChangedDate
  &$orderby=CreatedDate desc
```
To run the same query against an Azure DevOps Server, format as follows. Note this assumes https for the server.

```
https://<server>/<collection>/_odata/v3.0-preview/WorkItems?
  $select=WorkItemId,ProjectSK,Title,WorkItemType,State,CreatedDate,ChangedDate
  &$orderby=CreatedDate desc
```

