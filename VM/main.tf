#Create an Azure VM cluster with Terraform and HCL
#configure your environment

#resource group created
#managed configuration->RG->Resources-stgaccnt->vnet->subvnet
terraform {
  required_providers {

    azurerm = {

      source  = "hashicorp/azurerm"
      version = "~>2.99.0"
    }
  }
}
provider "azurerm" {
  features {}

}
#Resource Created
resource "azurerm_resource_group" "test-Rg1" {
  name     = "Rg-tf-demo"
  location = "CentralIndia"

}
#virtual network
resource "azurerm_virtual_network" "test-vnet" {
  name                = "VM-tf"
  location            = azurerm_resource_group.test-Rg1.location
  resource_group_name = azurerm_resource_group.test-Rg1.name
  address_space       = ["10.0.0.0/16"]
}
#subnet
resource "azurerm_subnet" "test-snet" {
  name                 = "acctsub"
  resource_group_name  = azurerm_resource_group.test-Rg1.name
  virtual_network_name = azurerm_virtual_network.test-vnet.name
  address_prefixes     = ["10.0.2.0/24"]

}
#public IP
resource "azurerm_public_ip" "test-pubip" {
  name                = "PublickIPforLB"
  location            = azurerm_resource_group.test-Rg1.location
  resource_group_name = azurerm_resource_group.test-Rg1.name
  allocation_method   = "Static"
}
resource "azurerm_lb" "testlb" {
  name                = "loadBalancer"
  location            = azurerm_resource_group.test-Rg1.location
  resource_group_name = azurerm_resource_group.test-Rg1.name
  frontend_ip_configuration {
    name                 = "publicIPAddress"
    public_ip_address_id = azurerm_public_ip.test-pubip.id

  }

}

#azure bakcend lb
resource "azurerm_lb_backend_address_pool" "test-lb" {
  loadbalancer_id = azurerm_lb.testlb.id
  name            = "BackendAddressPool"

}
#azuer NIC
resource "azurerm_network_interface" "test" {
  count               = 2
  name                = "acctni${count.index}"
  location            = azurerm_resource_group.test-Rg1.location
  resource_group_name = azurerm_resource_group.test-Rg1.name

  ip_configuration {
    name                          = "testConfiguration"
    subnet_id                     = azurerm_subnet.test-snet.id
    private_ip_address_allocation = "dynamic"
  }
}
# azure disk
resource "azurerm_managed_disk" "test" {
  count                = 2
  name                 = "datadisk_existing_${count.index}"
  location             = azurerm_resource_group.test-Rg1.location
  resource_group_name  = azurerm_resource_group.test-Rg1.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"
}
#azure availibilty

resource "azurerm_availability_set" "avset" {
  name                         = "avset"
  location                     = azurerm_resource_group.test-Rg1.location
  resource_group_name          = azurerm_resource_group.test-Rg1.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true

}
#VM 
resource "azurerm_virtual_machine" "test" {
  count                 = 2
  name                  = "acctvm${count.index}"
  location              = azurerm_resource_group.test-Rg1.location
  availability_set_id   = azurerm_availability_set.avset.id
  resource_group_name   = azurerm_resource_group.test-Rg1.name
  network_interface_ids = [element(azurerm_network_interface.test.*.id, count.index)]
  vm_size               = "Standard_DS1_v2"
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  # Optional data disks
  storage_data_disk {
    name              = "datadisk_new_${count.index}"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "1023"
  }

  storage_data_disk {
    name            = element(azurerm_managed_disk.test.*.name, count.index)
    managed_disk_id = element(azurerm_managed_disk.test.*.id, count.index)
    create_option   = "Attach"
    lun             = 1
    disk_size_gb    = element(azurerm_managed_disk.test.*.disk_size_gb, count.index)
  }


  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "stagingVM"
  }
}