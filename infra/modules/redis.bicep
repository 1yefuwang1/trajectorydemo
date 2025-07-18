// modules/redis.bicep
param name string
param location string
param subnetId string

resource redisCache 'Microsoft.Cache/Redis@2024-11-01' = {
  name: name
  location: location
  properties: {
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    sku: { 
      name: 'Premium'
      family: 'P'
      capacity: 1
    }
    subnetId: subnetId
  }
}

output hostName string = redisCache.properties.hostName

