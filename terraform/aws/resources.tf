resource "aws_vpc" "lattice" {
    cidr_block = "${var.aws_vpc_cidr_block}"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags {
        Name = "lattice"
    }
}

resource "aws_subnet" "lattice" {
    vpc_id = "${aws_vpc.lattice.id}"
    cidr_block = "${var.aws_subnet_cidr_block}"
    map_public_ip_on_launch = true
    tags {
        Name = "lattice"
    }
}

resource "aws_internet_gateway" "lattice" {
    vpc_id = "${aws_vpc.lattice.id}"
}

resource "aws_route_table" "lattice" {
    vpc_id = "${aws_vpc.lattice.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.lattice.id}"
    }
}

resource "aws_route_table_association" "lattice" {
    subnet_id = "${aws_subnet.lattice.id}"
    route_table_id = "${aws_route_table.lattice.id}"
}

resource "aws_security_group" "lattice" {
    name = "lattice"
    description = "lattice security group"
    vpc_id = "${aws_vpc.lattice.id}"
    ingress {
        protocol = "tcp"
        from_port = 1
        to_port = 65535
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        protocol = "udp"
        from_port = 1
        to_port = 65535
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags {
        Name = "lattice"
    }
}

resource "aws_instance" "lattice-coordinator" {
    ami = "${lookup(var.aws_image, var.aws_region)}"
    instance_type = "${var.aws_instance_type_coordinator}"
    key_name = "${var.aws_key_name}"
    subnet_id = "${aws_subnet.lattice.id}"
    security_groups = [
      "${aws_security_group.lattice.id}",
    ]
    tags {
        Name = "lattice-coordinator"
    }

    connection {
        user = "${var.aws_ssh_user}"
        key_file = "${var.aws_ssh_private_key_file}"
    }

#COMMON
    provisioner "local-exec" {
      command = "LOCAL_LATTICE_TAR_PATH=${var.local_lattice_tar_path} ${path.module}/../local-scripts/download-lattice-tar"
    }
    provisioner "file" {
      source = "${var.local_lattice_tar_path}"
      destination = "/tmp/lattice.tgz"
    }

    provisioner "file" {
      source = "${path.module}/../remote-scripts/install_from_tar"
      destination = "/tmp/install_from_tar"
    }

    provisioner "remote-exec" {
      inline = [
          "sudo chmod 755 /tmp/install_from_tar",
          "sudo bash -c \"echo 'PATH_TO_LATTICE_TAR=${var.local_lattice_tar_path}' >> /etc/environment\""
      ]
    }
#/COMMON

    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /var/lattice/setup",
            "sudo sh -c 'echo \"LATTICE_USERNAME=${var.lattice_username}\" > /var/lattice/setup/lattice-environment'",
            "sudo sh -c 'echo \"LATTICE_PASSWORD=${var.lattice_password}\" >> /var/lattice/setup/lattice-environment'",
            "sudo sh -c 'echo \"CONSUL_SERVER_IP=${aws_instance.lattice-coordinator.private_ip}\" >> /var/lattice/setup/lattice-environment'",
            "sudo sh -c 'echo \"SYSTEM_DOMAIN=${aws_instance.lattice-coordinator.public_ip}.xip.io\" >> /var/lattice/setup/lattice-environment'",
        ]
    }

    provisioner "remote-exec" {
        script = "${path.module}/../remote-scripts/install-lattice-coordinator"
    }
}

resource "aws_instance" "lattice-cell" {
    count = "${var.num_cells}"
    ami = "${lookup(var.aws_image, var.aws_region)}"
    instance_type = "${var.aws_instance_type_cell}"
    key_name = "${var.aws_key_name}"
    subnet_id = "${aws_subnet.lattice.id}"
    security_groups = [
      "${aws_security_group.lattice.id}",
    ]
    tags {
        Name = "lattice-cell-${count.index}"
    }

    connection {
        user = "${var.aws_ssh_user}"
        key_file = "${var.aws_ssh_private_key_file}"
    }

#COMMON
    provisioner "local-exec" {
        command = "sudo MODULE_PATH='${path.module}' LOCAL_LATTICE_TAR_PATH='${var.local_lattice_tar_path}' ${path.module}/../local-scripts/download-lattice-tar"
    }
    provisioner "file" {
        source = "${var.local_lattice_tar_path}"
        destination = "/tmp/lattice.tgz"
    }

    provisioner "file" {
        source = "${path.module}/../remote-scripts/install_from_tar"
        destination = "/tmp/install_from_tar"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo chmod 755 /tmp/install_from_tar",
            "sudo bash -c \"echo 'PATH_TO_LATTICE_TAR=${var.local_lattice_tar_path}' >> /etc/environment\""
        ]
    }
#/COMMON

    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /var/lattice/setup",
            "sudo sh -c 'echo \"LATTICE_USERNAME=${var.lattice_username}\" > /var/lattice/setup/lattice-environment'",
            "sudo sh -c 'echo \"LATTICE_PASSWORD=${var.lattice_password}\" >> /var/lattice/setup/lattice-environment'",
            "sudo sh -c 'echo \"CONSUL_SERVER_IP=${aws_instance.lattice-coordinator.private_ip}\" >> /var/lattice/setup/lattice-environment'",
            "sudo sh -c 'echo \"SYSTEM_DOMAIN=${aws_instance.lattice-coordinator.public_ip}.xip.io\" >> /var/lattice/setup/lattice-environment'",
            "sudo sh -c 'echo \"DIEGO_CELL_ID=lattice-cell-${count.index}\" >> /var/lattice/setup/lattice-environment'",
        ]
    }

    provisioner "remote-exec" {
        script = "${path.module}/../remote-scripts/install-lattice-cell"
    }

}
