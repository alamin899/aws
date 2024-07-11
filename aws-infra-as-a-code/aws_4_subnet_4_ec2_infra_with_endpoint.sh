#!/bin/bash

# Your AWS region
AWS_REGION="us-east-1"

#-----------------------------VPC Create and modify------------------------------------------------------
echo "Creating a VPC..."
vpc_id=$(aws ec2 create-vpc --cidr-block "30.30.0.0/16" --region $AWS_REGION --output json --query 'Vpc.VpcId')
vpc_id=$(echo "$vpc_id" | sed 's/"//g')
echo "VPC created with ID: $vpc_id"

aws ec2 modify-vpc-attribute --vpc-id $vpc_id --enable-dns-support "{\"Value\":true}" --output json
aws ec2 modify-vpc-attribute --vpc-id $vpc_id --enable-dns-hostnames "{\"Value\":true}" --output json
aws ec2 create-tags --resources $vpc_id --tags Key=Name,Value=robotics-vpc --output json
echo "DNS hostnames enabled for VPC."
#-------------------------------END VPC Create and modify--------------------------------------------------


#-------------------------------IGW Create and attach------------------------------------------------------
echo "Creating Internet Gateway for VPC..."
gateway_id=$(aws ec2 create-internet-gateway --region $AWS_REGION --output json --query 'InternetGateway.InternetGatewayId')
gateway_id=$(echo "$gateway_id" | sed 's/"//g')
aws ec2 create-tags --resources $gateway_id --tags Key=Name,Value=robotics-igw --output json
echo "Internet Gateway created with ID: $gateway_id"

aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $gateway_id --output json
echo "Internet Gateway attached to VPC."
#-------------------------------End IGW Create and modify------------------------------------------------------


#-------------------------------Create Public and private Subnet on zone us-east-1a-----------------------------------------------------------
echo "Creating public subnet in this VPC Zone us-east-1a..."
public_subnet_id1a=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block "30.30.0.0/20" --availability-zone ${AWS_REGION}a --region $AWS_REGION --output json --query 'Subnet.SubnetId')
public_subnet_id1a=$(echo "$public_subnet_id1a" | sed 's/"//g')
aws ec2 create-tags --resources $public_subnet_id1a --tags Key=Name,Value=robotics-public-subnet-1a --output json
echo "Success Public subnet1a created with ID: $public_subnet_id1a"

echo "Creating private subnet in this VPC Zone us-east-1a..."
private_subnet_id1a=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block "30.30.128.0/20" --availability-zone ${AWS_REGION}a --region $AWS_REGION --output json --query 'Subnet.SubnetId')
private_subnet_id1a=$(echo "$private_subnet_id1a" | sed 's/"//g')
aws ec2 create-tags --resources $private_subnet_id1a --tags Key=Name,Value=robotics-private-subnet1a --output json
echo "Success Private subnet1a created with ID: $private_subnet_id"
#-------------------------------End Public Subnet-----------------------------------------------------------

#-------------------------------Create Private Subnet on zone us-east-1b-----------------------------------------------------------
echo "Creating public subnet in this VPC Zone us-east-1b..."
public_subnet_id1b=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block "30.30.16.0/20" --availability-zone ${AWS_REGION}b --region $AWS_REGION --output json --query 'Subnet.SubnetId')
public_subnet_id1b=$(echo "$public_subnet_id1b" | sed 's/"//g')
aws ec2 create-tags --resources $public_subnet_id1b --tags Key=Name,Value=robotics-public-subnet-1b --output json
echo "Success Public subnet1b created with ID: $public_subnet_id1b"

echo "Creating private subnet in this VPC Zone us-east-1b..."
private_subnet_id1b=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block "30.30.144.0/20" --availability-zone ${AWS_REGION}b --region $AWS_REGION --output json --query 'Subnet.SubnetId')
private_subnet_id1b=$(echo "$private_subnet_id1b" | sed 's/"//g')
aws ec2 create-tags --resources $private_subnet_id1b --tags Key=Name,Value=robotics-private-subnet1b --output json
echo "Success Private subnet1b created with ID: $private_subnet_id1b"
#-------------------------------End Private Subnet-----------------------------------------------------------


#------------------Create public route  table and attach Internet Gateway in the Route Table-------
echo "Create Public Route Table from VPC..."
public_route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --output json --query 'RouteTable.RouteTableId')
public_route_table_id=$(echo "$public_route_table_id" | sed 's/"//g')
aws ec2 create-tags --resources $public_route_table_id --tags Key=Name,Value=robotics-public-route-table --output json
echo "Success Public Route Table with ID: $public_route_table_id"

assign_igw=$(aws ec2 create-route --route-table-id $public_route_table_id --destination-cidr-block "0.0.0.0/0" --gateway-id $gateway_id --region $AWS_REGION --output json --query 'Return')
assign_private_ip=$(aws ec2 create-route --route-table-id $public_route_table_id --destination-cidr-block "30.30.0.0/16" --instance-id $local_target_instance_id --output json --region $AWS_REGION --query 'Return')
echo "Success Public route added to Route Table for Internet access."
#------------------End Create oublic route  table and attach Internet Gateway in the Route Table-------

#------------------Create private route  table and attach Routing ---------------------------------
echo "Create Private Route Table from VPC..."
private_route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --output json --query 'RouteTable.RouteTableId')
private_route_table_id=$(echo "$private_route_table_id" | sed 's/"//g')
aws ec2 create-tags --resources $private_route_table_id --tags Key=Name,Value=robotics-private-route-table --output json
echo "Success Private Route Table with ID: $private_route_table_id"

assign_private_ip=$(aws ec2 create-route --route-table-id $private_route_table_id --destination-cidr-block "30.30.0.0/16" --instance-id $local_target_instance_id --output json --region $AWS_REGION --query 'Return')
echo "Default route added to Route Table for Internet access."
#------------------End Create oublic route  table and attach Internet Gateway in the Route Table-------

#------------------Create s3 endpoint and attach to private route---------------------------------
echo "Creating VPC Endpoint..."
aws ec2 create-vpc-endpoint --vpc-id $vpc_id --service-name com.amazonaws.us-east-1.s3 --vpc-endpoint-type Gateway --route-table-ids $private_route_table_id 
echo "Sucess Created VPC Endpoint..."
#------------------End s3 endpoint and attach to private route---------------------------------


#------------------Start Public Route table associated with subnet------------------------------------------------
echo "Assining route table to public subnet1a..."
aws ec2 associate-route-table --subnet-id $public_subnet_id1a --route-table-id $public_route_table_id --output json
echo "Successfully Assign route table to public subnet1a..."

echo "Assining route table to public subnet1b..."
aws ec2 associate-route-table --subnet-id $public_subnet_id1b --route-table-id $public_route_table_id --output json
echo "Successfully Assign route table to public subnet1b..."
#------------------End Public Route table associated with subnet------------------------------------------------


#------------------Start Private Route table associated with subnet------------------------------------------------
echo "Assining route table to private subnet1a..."
aws ec2 associate-route-table --subnet-id $private_subnet_id1a --route-table-id $private_route_table_id --output json
echo "Successfully Assign route table to private subnet1a..."

echo "Assining route table to private subnet1b..."
aws ec2 associate-route-table --subnet-id $private_subnet_id1b --route-table-id $private_route_table_id --output json
echo "Successfully Assign route table to private subnet1b..."
#------------------End Private Route table associated with subnet------------------------------------------------

echo "\n\n"

#--------------Start Private Key pair create---------------------------------------------------------
aws ec2 create-key-pair --key-name alamin --query 'KeyMaterial' --output text >alamin.pem
echo "alamin key pair create"
#--------------End Private Key pair create---------------------------------------------------------


#---------------Start Create SG for EC2 Machine----------------------------------------------------------------------
sg_id=$(aws ec2 create-security-group --group-name "robotics-sg" --description "robotics-sg-for-vpc" --vpc-id $vpc_id --output json --query 'GroupId')
sg_id=$(echo "$sg_id" | sed 's/"//g')
aws ec2 create-tags --resources $sg_id --tags Key=Name,Value=robotics-sg --output json
sg_icmp=$(aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol icmp --port -1 --cidr "0.0.0.0/0" --output json --query 'Return')
sg_ssh=$(aws ec2 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 22 --cidr "0.0.0.0/0" --output json --query 'Return')
echo "Create a security group & the ID is: $sg_id"
#---------------End Create SG for EC2 Machine----------------------------------------------------------------------


#---------------Create Public and Private EC2 Machine us-east-1a----------------------------------------------------------------------
echo "Creating public instance for us-east-1a"
public_instance_id1a=$(aws ec2 run-instances \
    --image-id ami-053b0d53c279acc90 \
    --instance-type t2.micro \
    --subnet-id $public_subnet_id1a \
    --key-name alamin \
    --security-group-ids $sg_id \
    --associate-public-ip-address \
    --region $AWS_REGION \
    --output json \
    --query 'Instances[0].InstanceId')

public_instance_id1a=$(echo "$public_instance_id1a" | sed 's/"//g')
aws ec2 create-tags --resources $public_instance_id1a --tags Key=Name,Value=robotics-public-instance-1a --output json
echo "public instance for us-east-1a create ID: $public_instance_id1a"

echo "Creating private instance for us-east-1a"
private_instance_id1a=$(aws ec2 run-instances \
    --image-id ami-053b0d53c279acc90 \
    --instance-type t2.micro \
    --subnet-id $private_subnet_id1a \
    --key-name alamin \
    --security-group-ids $sg_id \
    --region $AWS_REGION \
    --output json \
    --query 'Instances[0].InstanceId')

private_instance_id1a=$(echo "$private_instance_id1a" | sed 's/"//g')
aws ec2 create-tags --resources $private_instance_id1a --tags Key=Name,Value=robotics-private-instance-1a --output json
echo "Success private instance for us-east-1a create ID: $private_instance_id1a"
#---------------End Create Public and private EC2 Machine----------------------------------------------------------------------


#---------------Create Public and Private EC2 Machine for us-east-1b----------------------------------------------------------------------
echo "Creating public instance for us-east-1b"
public_instance_id1b=$(aws ec2 run-instances \
    --image-id ami-053b0d53c279acc90 \
    --instance-type t2.micro \
    --subnet-id $public_subnet_id1b \
    --key-name alamin \
    --security-group-ids $sg_id \
    --associate-public-ip-address \
    --region $AWS_REGION \
    --output json \
    --query 'Instances[0].InstanceId')

public_instance_id1b=$(echo "$public_instance_id1b" | sed 's/"//g')
aws ec2 create-tags --resources $public_instance_id1b --tags Key=Name,Value=robotics-public-instance-1b --output json
echo "public instance for us-east-1b create ID: $public_instance_id1b"

echo "Creating private instance for us-east-1a"
private_instance_id1b=$(aws ec2 run-instances \
    --image-id ami-053b0d53c279acc90 \
    --instance-type t2.micro \
    --subnet-id $private_subnet_id1b \
    --key-name alamin \
    --security-group-ids $sg_id \
    --region $AWS_REGION \
    --output json \
    --query 'Instances[0].InstanceId')

private_instance_id1b=$(echo "$private_instance_id1a" | sed 's/"//g')
aws ec2 create-tags --resources $private_instance_id1b --tags Key=Name,Value=robotics-private-instance-1b --output json
echo "Success private instance for us-east-1b create ID: $private_instance_id1b"
#---------------End Create Public and Private EC2 Machine for us-east-1b----------------------------------------------------------------------
