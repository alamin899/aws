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


#-------------------------------Create Public Subnet-----------------------------------------------------------
echo "Creating public subnet in this VPC..."
public_subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block "30.30.1.0/20" --availability-zone ${AWS_REGION}a --region $AWS_REGION --output json --query 'Subnet.SubnetId')
public_subnet_id=$(echo "$public_subnet_id" | sed 's/"//g')
aws ec2 create-tags --resources $public_subnet_id --tags Key=Name,Value=robotics-public-subnet --output json
echo "Public subnet created with ID: $public_subnet_id"
#-------------------------------End Public Subnet-----------------------------------------------------------

#-------------------------------Create Private Subnet-----------------------------------------------------------
echo "Creating private subnet in this VPC..."
private_subnet_id=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block "30.30.128.0/20" --availability-zone ${AWS_REGION}a --region $AWS_REGION --output json --query 'Subnet.SubnetId')
private_subnet_id=$(echo "$private_subnet_id" | sed 's/"//g')
aws ec2 create-tags --resources $private_subnet_id --tags Key=Name,Value=robotics-private-subnet --output json
echo "Private subnet created with ID: $private_subnet_id"
#-------------------------------End Private Subnet-----------------------------------------------------------


#------------------Create public route  table and attach Internet Gateway in the Route Table-------
echo "Create Public Route Table from VPC..."
public_route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --output json --query 'RouteTable.RouteTableId')
public_route_table_id=$(echo "$public_route_table_id" | sed 's/"//g')
aws ec2 create-tags --resources $public_route_table_id --tags Key=Name,Value=robotics-public-route-table --output json
echo "Public Route Table with ID: $public_route_table_id"

assign_igw=$(aws ec2 create-route --route-table-id $public_route_table_id --destination-cidr-block "0.0.0.0/0" --gateway-id $gateway_id --output json --region $AWS_REGION --query 'Return')
assign_private_ip=$(aws ec2 create-route --route-table-id $public_route_table_id --destination-cidr-block "30.30.0.0/16" --instance-id $local_target_instance_id --output json --region $AWS_REGION --query 'Return')
echo "Default route added to Route Table for Internet access."
#------------------End Create oublic route  table and attach Internet Gateway in the Route Table-------

#------------------Create private route  table and attach Routing ---------------------------------
echo "Create Route Table from VPC..."
private_route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --output json --query 'RouteTable.RouteTableId')
private_route_table_id=$(echo "$private_route_table_id" | sed 's/"//g')
aws ec2 create-tags --resources $private_route_table_id --tags Key=Name,Value=robotics-private-route-table --output json
echo "Public Route Table with ID: $private_route_table_id"

assign_private_ip=$(aws ec2 create-route --route-table-id $private_route_table_id --destination-cidr-block "30.30.0.0/16" --instance-id $local_target_instance_id --output json --region $AWS_REGION --query 'Return')
echo "Default route added to Route Table for Internet access."
#------------------End Create oublic route  table and attach Internet Gateway in the Route Table-------


#------------------Start Route table associated with subnet------------------------------------------------
echo "Assining route table to public subnet..."
aws ec2 associate-route-table --subnet-id $public_subnet_id --route-table-id $public_route_table_id --output json
echo "Successfully Assign route table to public subnet..."

echo "Assining route table to private subnet..."
aws ec2 associate-route-table --subnet-id $private_subnet_id --route-table-id $private_route_table_id --output json
echo "Successfully Assign route table to private subnet..."

#------------------End Route table associated with subnet------------------------------------------------

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


#---------------Create Public EC2 Machine----------------------------------------------------------------------
public_instance_id=$(aws ec2 run-instances \
    --image-id ami-053b0d53c279acc90 \
    --instance-type t2.micro \
    --subnet-id $public_subnet_id \
    --key-name alamin \
    --security-group-ids $sg_id \
    --associate-public-ip-address \
    --region $AWS_REGION \
    --output json \
    --query 'Instances[0].InstanceId')

public_instance_id=$(echo "$public_instance_id" | sed 's/"//g')
aws ec2 create-tags --resources $public_instance_id --tags Key=Name,Value=robotics-public-instance --output json
echo "public instance create ID: $public_instance_id"
#---------------End Create Public EC2 Machine----------------------------------------------------------------------


#---------------Create Private EC2 Machine----------------------------------------------------------------------
private_instance_id=$(aws ec2 run-instances \
    --image-id ami-053b0d53c279acc90 \
    --instance-type t2.micro \
    --subnet-id $private_subnet_id \
    --key-name poridhi \
    --security-group-ids $sg_id \
    --region $AWS_REGION \
    --output json \
    --query 'Instances[0].InstanceId')

private_instance_id=$(echo "$private_instance_id" | sed 's/"//g')
aws ec2 create-tags --resources $private_instance_id --tags Key=Name,Value=robotics-private-instance --output json
echo "private instance create ID: $private_instance_id"
#---------------End Create Private EC2 Machine----------------------------------------------------------------------
