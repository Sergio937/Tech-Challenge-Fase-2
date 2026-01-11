# Script PowerShell para provisionar infraestrutura AWS do zero usando AWS CLI, kubectl e Helm
# Pré-requisitos: AWS CLI, kubectl, Helm instalados e configurados

# 1. Criar VPC customizada

# ===================== VARIÁVEIS E INTERAÇÃO =====================
if (-not $region) { $region = Read-Host 'Informe a região AWS (ex: us-east-1)' }
if (-not $vpcCidr) { $vpcCidr = Read-Host 'Informe o CIDR da VPC (ex: 10.0.0.0/16)' }
if (-not $subnetPublicCidr) { $subnetPublicCidr = Read-Host 'Informe o CIDR da subnet pública (ex: 10.0.1.0/24)' }
if (-not $subnetPrivateCidr) { $subnetPrivateCidr = Read-Host 'Informe o CIDR da subnet privada (ex: 10.0.2.0/24)' }
if (-not $eksClusterName) { $eksClusterName = Read-Host 'Informe o nome do cluster EKS' }
if (-not $eksRoleArn -or $eksRoleArn -like '<*') { $eksRoleArn = Read-Host 'Informe o ARN da role EKS' }
if (-not $nodeRoleArn -or $nodeRoleArn -like '<*') { $nodeRoleArn = Read-Host 'Informe o ARN da role dos nodes' }
if (-not $dbUser) { $dbUser = Read-Host 'Informe o usuário do banco RDS' }
if (-not $dbPassword -or $dbPassword -eq 'SenhaForte123!') { $dbPassword = Read-Host 'Informe a senha do banco RDS' }
if (-not $dbSubnetGroup) { $dbSubnetGroup = Read-Host 'Informe o nome do DB Subnet Group' }
if (-not $dynamoTable) { $dynamoTable = Read-Host 'Informe o nome da tabela DynamoDB' }
if (-not $sqsQueue) { $sqsQueue = Read-Host 'Informe o nome da fila SQS' }


Write-Host "\n==== ETAPA 1: VPC ===="
$proceed = Read-Host 'Deseja criar a VPC? (s/n)'
if ($proceed -eq 's') {
	$vpcId = $(aws ec2 create-vpc --cidr-block $vpcCidr --region $region --query 'Vpc.VpcId' --output text)
	aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-support '{"Value":true}'
	aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames '{"Value":true}'
	Write-Host "VPC criada: $vpcId"
} else {
	$vpcId = Read-Host 'Informe o VpcId já existente para usar nas próximas etapas'
}


Write-Host "\n==== ETAPA 2: Subnets ===="
$proceed = Read-Host 'Deseja criar as subnets? (s/n)'
if ($proceed -eq 's') {
	$subnetPublic = $(aws ec2 create-subnet --vpc-id $vpcId --cidr-block $subnetPublicCidr --availability-zone "$region"a --query 'Subnet.SubnetId' --output text)
	$subnetPrivate = $(aws ec2 create-subnet --vpc-id $vpcId --cidr-block $subnetPrivateCidr --availability-zone "$region"a --query 'Subnet.SubnetId' --output text)
	Write-Host "Subnet pública: $subnetPublic"
	Write-Host "Subnet privada: $subnetPrivate"
} else {
	$subnetPublic = Read-Host 'Informe o SubnetId da subnet pública'
	$subnetPrivate = Read-Host 'Informe o SubnetId da subnet privada'
}


Write-Host "\n==== ETAPA 3: Grupo de Segurança ===="
$proceed = Read-Host 'Deseja criar o grupo de segurança? (s/n)'
if ($proceed -eq 's') {
	$sgEKS = $(aws ec2 create-security-group --group-name sg-eks --description "SG para EKS" --vpc-id $vpcId --query 'GroupId' --output text)
	aws ec2 authorize-security-group-ingress --group-id $sgEKS --protocol tcp --port 443 --cidr 0.0.0.0/0
	Write-Host "Grupo de segurança criado: $sgEKS"
} else {
	$sgEKS = Read-Host 'Informe o GroupId do grupo de segurança a ser usado'
}


Write-Host "\n==== ETAPA 4: EKS Cluster ===="
$proceed = Read-Host 'Deseja criar o cluster EKS? (s/n)'
if ($proceed -eq 's') {
	aws eks create-cluster --name $eksClusterName --role-arn $eksRoleArn --resources-vpc-config subnetIds=$subnetPublic,$subnetPrivate,securityGroupIds=$sgEKS --region $region
	aws eks wait cluster-active --name $eksClusterName --region $region
	Write-Host "Cluster EKS criado: $eksClusterName"
} else {
	Write-Host 'Pulando criação do cluster EKS.'
}


Write-Host "\n==== ETAPA 5: Node Group ===="
$proceed = Read-Host 'Deseja criar o node group? (s/n)'
if ($proceed -eq 's') {
	aws eks create-nodegroup --cluster-name $eksClusterName --nodegroup-name "ng1" --subnets $subnetPublic $subnetPrivate --node-role $nodeRoleArn --scaling-config minSize=1,maxSize=2,desiredSize=1 --region $region
	aws eks wait nodegroup-active --cluster-name $eksClusterName --nodegroup-name "ng1" --region $region
	Write-Host "Node group criado."
} else {
	Write-Host 'Pulando criação do node group.'
}


Write-Host "\n==== ETAPA 6: Atualizar kubeconfig ===="
$proceed = Read-Host 'Deseja atualizar o kubeconfig? (s/n)'
if ($proceed -eq 's') {
	aws eks update-kubeconfig --name $eksClusterName --region $region
	Write-Host "kubeconfig atualizado."
} else {
	Write-Host 'Pulando atualização do kubeconfig.'
}


Write-Host "\n==== ETAPA 7: RDS PostgreSQL ===="
$proceed = Read-Host 'Deseja criar as 3 instâncias RDS PostgreSQL (auth, flag, targeting)? (s/n)'
if ($proceed -eq 's') {
	$subnet1 = Read-Host 'Informe o SubnetId privado 1 para o DB Subnet Group'
	$subnet2 = Read-Host 'Informe o SubnetId privado 2 para o DB Subnet Group'
	aws rds create-db-subnet-group --db-subnet-group-name $dbSubnetGroup --subnet-ids $subnet1 $subnet2 --description "DB subnet group"

	$authPass = Read-Host 'Senha do banco AUTH (authuser)'
	$flagPass = Read-Host 'Senha do banco FLAG (flaguser)'
	$targetingPass = Read-Host 'Senha do banco TARGETING (targetinguser)'

	aws rds create-db-instance --db-instance-identifier auth-postgres --db-instance-class db.t3.micro --engine postgres --master-username authuser --master-user-password $authPass --allocated-storage 20 --vpc-security-group-ids $sgEKS --db-subnet-group-name $dbSubnetGroup --region $region
	aws rds create-db-instance --db-instance-identifier flag-postgres --db-instance-class db.t3.micro --engine postgres --master-username flaguser --master-user-password $flagPass --allocated-storage 20 --vpc-security-group-ids $sgEKS --db-subnet-group-name $dbSubnetGroup --region $region
	aws rds create-db-instance --db-instance-identifier targeting-postgres --db-instance-class db.t3.micro --engine postgres --master-username targetinguser --master-user-password $targetingPass --allocated-storage 20 --vpc-security-group-ids $sgEKS --db-subnet-group-name $dbSubnetGroup --region $region
	Write-Host "As 3 instâncias RDS PostgreSQL foram criadas."
} else {
	Write-Host 'Pulando criação das instâncias RDS.'
}


Write-Host "\n==== ETAPA 8: DynamoDB ===="
$proceed = Read-Host 'Deseja criar a tabela DynamoDB? (s/n)'
if ($proceed -eq 's') {
	aws dynamodb create-table --table-name $dynamoTable --attribute-definitions AttributeName=Id,AttributeType=S --key-schema AttributeName=Id,KeyType=HASH --billing-mode PAY_PER_REQUEST --region $region
	Write-Host "Tabela DynamoDB criada."
} else {
	Write-Host 'Pulando criação da tabela DynamoDB.'
}


Write-Host "\n==== ETAPA 9: SQS ===="
$proceed = Read-Host 'Deseja criar a fila SQS? (s/n)'
if ($proceed -eq 's') {
	aws sqs create-queue --queue-name $sqsQueue --region $region
	Write-Host "Fila SQS criada."
} else {
	Write-Host 'Pulando criação da fila SQS.'
}


Write-Host "\n==== ETAPA 10: metrics-server ===="
$proceed = Read-Host 'Deseja instalar o metrics-server? (s/n)'
if ($proceed -eq 's') {
	kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
	Write-Host "metrics-server instalado."
} else {
	Write-Host 'Pulando metrics-server.'
}


Write-Host "\n==== ETAPA 11: Ingress Controller (ALB) ===="
$proceed = Read-Host 'Deseja instalar o ingress controller (ALB)? (s/n)'
if ($proceed -eq 's') {
	kubectl apply -f https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/latest/download/v2_6_2_full.yaml
	Write-Host "Ingress controller instalado."
} else {
	Write-Host 'Pulando ingress controller.'
}


Write-Host "\n==== ETAPA 12: HPA ===="
$proceed = Read-Host 'Deseja aplicar o HPA? (s/n)'
if ($proceed -eq 's') {
	$hpaManifest = Read-Host 'Informe o caminho do manifest HPA (ex: ./analytics-service/analytics-hpa.yaml)'
	kubectl apply -f $hpaManifest
	Write-Host "HPA aplicado."
} else {
	Write-Host 'Pulando HPA.'
}


Write-Host "\n==== ETAPA 13: Manifests do Projeto ===="
$proceed = Read-Host 'Deseja aplicar todos os manifests do projeto? (s/n)'
if ($proceed -eq 's') {
	.\deploy-all.ps1
	Write-Host "Manifests aplicados."
} else {
	Write-Host 'Pulando aplicação dos manifests.'
}

Write-Host "\nProvisionamento inicial concluído. Edite as variáveis no topo conforme necessário."
# (Salve o VpcId retornado para usar nos próximos comandos)

# 2. Criar sub-redes públicas e privadas
# Exemplo para uma subnet pública
# aws ec2 create-subnet --vpc-id <VpcId> --cidr-block 10.0.1.0/24 --availability-zone us-east-1a
# Repita para outras subnets públicas e privadas

# 3. Criar grupos de segurança privados
# Exemplo:
# aws ec2 create-security-group --group-name sg-eks-private --description "SG para EKS privado" --vpc-id <VpcId>

# 4. Criar cluster EKS
# aws eks create-cluster --name meu-cluster --role-arn <EKSRoleARN> --resources-vpc-config subnetIds=<subnet-ids>,securityGroupIds=<sg-ids>

# 5. Criar node group
# aws eks create-nodegroup --cluster-name meu-cluster --nodegroup-name meu-nodegroup --subnets <subnet-ids> --node-role <NodeInstanceRoleARN> --scaling-config minSize=1,maxSize=3,desiredSize=2

# 6. Atualizar kubeconfig
# aws eks update-kubeconfig --name meu-cluster

# 7. Criar RDS
# aws rds create-db-instance --db-instance-identifier meu-db --db-instance-class db.t3.micro --engine postgres --master-username admin --master-user-password <senha> --allocated-storage 20 --vpc-security-group-ids <sg-id> --db-subnet-group-name <subnet-group>

# 8. Criar tabela DynamoDB
# aws dynamodb create-table --table-name minha-tabela --attribute-definitions AttributeName=Id,AttributeType=S --key-schema AttributeName=Id,KeyType=HASH --billing-mode PAY_PER_REQUEST

# 9. Criar fila SQS
# aws sqs create-queue --queue-name minha-fila


# 10. Instalar metrics-server (para HPA funcionar)
# kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 11. Instalar ingress controller (ALB)
# kubectl apply -f https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/latest/download/v2_6_2_full.yaml

# 12. Aplicar HPA (Horizontal Pod Autoscaler)
# kubectl apply -f <manifest-hpa.yaml>

# 13. Aplicar manifests do projeto
# .\deploy-all.ps1

Write-Host "\nProvisionamento inicial concluído. Complete os parâmetros e execute cada etapa conforme necessário."
