#
# Copyright (c) 2022, Xilin Wu <wuxilin123@gmail.com>
#
# SPDX-License-Identifier: BSD-2-Clause-Patent
#

#
# Board specific initialization
#
INF custRkPkg/Drivers/BoardInitDxe3588test/BoardInitDxe.inf

#
# ACPI Support
#
INF MdeModulePkg/Universal/Acpi/AcpiTableDxe/AcpiTableDxe.inf
INF MdeModulePkg/Universal/Acpi/BootGraphicsResourceTableDxe/BootGraphicsResourceTableDxe.inf
INF custRkPkg/Drivers/PlatformAcpiDxe/PlatformAcpiDxe.inf
INF RuleOverride = ACPITABLE custRkPkg/AcpiTables/rock3a.inf

#
# SMBIOS Support
#
INF custRkPkg/Drivers/PlatformSmbiosDxe/PlatformSmbiosDxe.inf
INF MdeModulePkg/Universal/SmbiosDxe/SmbiosDxe.inf

INF custRkPkg/Drivers/LogoDxe/LogoDxe.inf
