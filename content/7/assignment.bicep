param parRoleDefinitionId string
param parPrincipalId string

resource ra 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${parRoleDefinitionId}/${parPrincipalId}')
  properties: {
    roleDefinitionId: parRoleDefinitionId
    principalId: parPrincipalId
  }
}
