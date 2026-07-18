`EndpointSlice` is now the primary mechanism, while the old `Endpoints` resource is considered legacy and is gradually being phased out.

create a service with no selector
view that it has no endpoints
requests won't work
create a pod
create an endpoint slice associated with the service - how to associate? - and put pod ip as its address
now requests work
note: this is not how we usually work - this is just for understanding
the endpoint slice is owned by the service, so it will be automatically deleted if you delete the service

now let's create a service with selector
first, create a deployment with some replicas
then create the service
note that the endpoint slice is automatically created
scale to 101+ replicas
view that it created additional endpoint slice (each slice can reference up to 100 endpoints)
