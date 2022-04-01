/** @file
*  Differentiated System Description Table Fields (DSDT) for RADXA Rock 3A.
*
*  Copyright (c) 2022, Jared McNeill <jmcneill@invisible.ca>
*  Copyright (c) 2022, Xilin Wu <wuxilin123@gmail.com>
*
*  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <IndustryStandard/Acpi64.h>

DefinitionBlock ("DsdtTable.aml", "DSDT",
                 EFI_ACPI_6_4_DIFFERENTIATED_SYSTEM_DESCRIPTION_TABLE_REVISION,
                 "RKCP  ", "RK356X  ", FixedPcdGet32 (PcdAcpiDefaultOemRevision)) {
  Scope (_SB) {

    include ("../rk356x/Cpu.asl")
    include ("../rk356x/Tsadc.asl")
    include ("../rk356x/Uart.asl")
    // USB2 crashes Windows
    // include ("Usb2.asl")
    include ("../rk356x/Usb3.asl")
    include ("../rk356x/Gmac.asl")
    include ("../rk356x/Mshc.asl")
    include ("../rk356x/Emmc.asl")
    include ("../rk356x/Pcie3x1.asl")

  } // Scope (_SB)
}
