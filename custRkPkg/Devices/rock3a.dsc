[Defines]
  PLATFORM_NAME                  = custRkPkg
  PLATFORM_GUID                  = 28f1a3bf-193a-47e3-a7b9-5a435eaab2ee
  PLATFORM_VERSION               = 1.0
  DSC_SPECIFICATION              = 0x0001001A
  OUTPUT_DIRECTORY               = Build/$(PLATFORM_NAME)
  SUPPORTED_ARCHITECTURES        = AARCH64
  BUILD_TARGETS                  = DEBUG|RELEASE
  SKUID_IDENTIFIER               = DEFAULT
  FLASH_DEFINITION               = custRkPkg/Devices/SoC/rk356x.fdf
  BOARD_DXE_FV_COMPONENTS        = custRkPkg/Devices/rock3a.fdf.inc

!include custRkPkg/Devices/SoC/rk356x.dsc

[BuildOptions.common]
  GCC:*_*_AARCH64_CC_FLAGS = -DENABLE_SIMPLE_INIT -DRK356X

[PcdsFixedAtBuild.common]
  # Simple Init
  gSimpleInitTokenSpaceGuid.PcdGuiDefaultDPI|300

  # Device Information
  gcustRkPkgTokenSpaceGuid.PcdDeviceVendor|"RADXA"
  gcustRkPkgTokenSpaceGuid.PcdDeviceProduct|"Rock3"
  gcustRkPkgTokenSpaceGuid.PcdDeviceCodeName|"rock3a"
  gcustRkPkgTokenSpaceGuid.PcdPlatformName|"RADXA ROCK3 Model A"
  gcustRkPkgTokenSpaceGuid.PcdCpuName|"Rockchip RK3568 (Cortex-A55)"

  #
  # USB support
  #
  gcustRkPkgTokenSpaceGuid.PcdOhc0Status|0xF
  gcustRkPkgTokenSpaceGuid.PcdOhc1Status|0xF
  gcustRkPkgTokenSpaceGuid.PcdEhc0Status|0xF
  gcustRkPkgTokenSpaceGuid.PcdEhc1Status|0xF
  gcustRkPkgTokenSpaceGuid.PcdXhc0Status|0xF
  gcustRkPkgTokenSpaceGuid.PcdXhc1Status|0xF

  #
  # PCI support
  #
  gEfiMdePkgTokenSpaceGuid.PcdPciExpressBaseAddress|0x0000000380000000
  gArmTokenSpaceGuid.PcdPciBusMin|0
  # TODO: fix
  gArmTokenSpaceGuid.PcdPciBusMax|1
  gArmTokenSpaceGuid.PcdPciMmio32Base|0xF0000000
  gArmTokenSpaceGuid.PcdPciMmio32Size|0x02000000
  gArmTokenSpaceGuid.PcdPciMmio64Base|0x0000000390000000
  gArmTokenSpaceGuid.PcdPciMmio64Size|0x000000002FFF0000
  gArmTokenSpaceGuid.PcdPciIoBase|0x0000
  gArmTokenSpaceGuid.PcdPciIoSize|0x10000
  gEmbeddedTokenSpaceGuid.PcdPrePiCpuIoSize|34

  gEfiMdePkgTokenSpaceGuid.PcdPciIoTranslation|0x00000003BFFF0000
  gcustRkPkgTokenSpaceGuid.PcdPcieResetGpioBank|2
  gcustRkPkgTokenSpaceGuid.PcdPcieResetGpioPin|30
  gcustRkPkgTokenSpaceGuid.PcdPciePowerGpioBank|0
  gcustRkPkgTokenSpaceGuid.PcdPciePowerGpioPin|28
  gcustRkPkgTokenSpaceGuid.PcdPcieLinkSpeed|1
  gcustRkPkgTokenSpaceGuid.PcdPcieNumLanes|1

[Components.common]
  #
  # Board specific
  #
  custRkPkg/Drivers/BoardInitDxe/BoardInitDxe.inf

  #
  # SD
  #
  # TODO: fix errors when SD card is not present
  EmbeddedPkg/Universal/MmcDxe/MmcDxe.inf
  custRkPkg/Drivers/MshcDxe/MshcDxe.inf

  #
  # eMMC
  #
  MdeModulePkg/Bus/Pci/SdMmcPciHcDxe/SdMmcPciHcDxe.inf
  MdeModulePkg/Bus/Sd/EmmcDxe/EmmcDxe.inf
  custRkPkg/Drivers/EmmcDxe/EmmcDxe.inf

  #
  # ACPI Support
  #
  MdeModulePkg/Universal/Acpi/AcpiTableDxe/AcpiTableDxe.inf
  MdeModulePkg/Universal/Acpi/BootGraphicsResourceTableDxe/BootGraphicsResourceTableDxe.inf
  custRkPkg/Drivers/PlatformAcpiDxe/PlatformAcpiDxe.inf
  custRkPkg/AcpiTables/rock3a.inf

  #
  # SMBIOS Support
  #
  custRkPkg/Drivers/PlatformSmbiosDxe/PlatformSmbiosDxe.inf
  MdeModulePkg/Universal/SmbiosDxe/SmbiosDxe.inf

