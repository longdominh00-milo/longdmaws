aws ecs create-service \
    --cluster lab14-cicd-cluster \
    --service-name svc-02 \
    --task-definition lab14-cicd-td:3 \
    --deployment-controller type=CODE_DEPLOY \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[	
subnet-09e50aba6cf63886d,subnet-083f90bd91a84147f],securityGroups=[sg-0f2e0fa6559af921a],assignPublicIp=DISABLED}" \
    --load-balancers "[{\"targetGroupArn\": \"arn:aws:elasticloadbalancing:ap-southeast-2:848989864871:targetgroup/tg-blue/91713e16bcdaaa15\", \"containerName\": \"demo-01\", \"containerPort\": 3001}]"