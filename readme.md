docker push commands

docker tag 69a4a38c6e5e  us.icr.io/fineract-ns/fineract:latest
docker push us.icr.io/fineract-ns/fineract:latest


helm dep up fineract 
helm package fineract     

helm repo index .


 helm upgrade -f fineract-ibank/values.yaml fineract fineract  --install