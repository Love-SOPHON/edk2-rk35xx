/** @file

  Copyright 2017, 2020 NXP
  Copyright 2021, Jared McNeill <jmcneill@invisible.ca>

  SPDX-License-Identifier: BSD-2-Clause-Patent

**/

#include <PiDxe.h>
#include <Library/BaseLib.h>
#include <Library/PrintLib.h>
#include <Library/DebugLib.h>
#include <Library/IoLib.h>
#include <Library/CruLib.h>
#include <Library/GpioLib.h>
#include <Library/MultiPhyLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <IndustryStandard/Pci.h>
#include <IndustryStandard/Rk35xx.h>
#include "PciHostBridgeInit.h"

/* APB Registers */
#define PCIE_CLIENT_GENERAL_CON         0x0000
#define  DEVICE_TYPE_SHIFT              4
#define  DEVICE_TYPE_MASK               (0xFU << DEVICE_TYPE_SHIFT)
#define  DEVICE_TYPE_RC                 (4 << DEVICE_TYPE_SHIFT)
#define  LINK_REQ_RST_GRT               BIT3
#define  LTSSM_ENABLE                   BIT2
#define PCIE_CLIENT_GENERAL_DEBUG_INFO  0x0104
#define PCIE_CLIENT_HOT_RESET_CTRL      0x0180
#define  APP_LSSTM_ENABLE_ENHANCE       BIT4
#define PCIE_CLIENT_LTSSM_STATUS        0x0300
#define  RDLH_LINK_UP                   BIT17
#define  SMLH_LINK_UP                   BIT16
#define  SMLH_LTSSM_STATE_MASK          0x3f
#define  SMLH_LTSSM_STATE_LINK_UP       0x11

/* DBI Registers */
#define PCI_DEVICE_CLASS                0x000A
#define PCIE_LINK_CAPABILITY            0x007C
#define PCIE_LINK_STATUS                0x0080
#define  LINK_STATUS_WIDTH_SHIFT        20
#define  LINK_STATUS_WIDTH_MASK         (0xFU << LINK_STATUS_WIDTH_SHIFT)
#define  LINK_STATUS_SPEED_SHIFT        16
#define  LINK_STATUS_SPEED_MASK         (0xFU << LINK_STATUS_SPEED_SHIFT)
#define PCIE_LINK_CTL_2                 0x00A0
#define PL_GEN2_CTRL_OFF                0x080C
#define  DIRECT_SPEED_CHANGE            BIT17
#define PL_MISC_CONTROL_1_OFF           0x08BC
#define  DBI_RO_WR_EN                   BIT0

/* ATU Registers */
#define ATU_CAP_BASE                    0x300000
#define IATU_REGION_CTRL_OUTBOUND(n)    (ATU_CAP_BASE + ((n) << 9))
#define IATU_REGION_CTRL_INBOUND(n)     (ATU_CAP_BASE + ((n) << 9) + 0x100)
#define IATU_REGION_CTRL_1_OFF          0x000
#define  IATU_TYPE_MEM                  0
#define  IATU_TYPE_IO                   2
#define  IATU_TYPE_CFG0                 4
#define  IATU_TYPE_CFG1                 5
#define IATU_REGION_CTRL_2_OFF          0x004
#define  IATU_ENABLE                    BIT31
#define  IATU_CFG_SHIFT_MODE            BIT28
#define IATU_LWR_BASE_ADDR_OFF          0x008
#define IATU_UPPER_BASE_ADDR_OFF        0x00C
#define IATU_LIMIT_ADDR_OFF             0x010
#define IATU_LWR_TARGET_ADDR_OFF        0x014
#define IATU_UPPER_TARGET_ADDR_OFF      0x018

#define PCIE_POWER_GPIO_BANK            FixedPcdGet32 (PcdPciePowerGpioBank)
#define PCIE_POWER_GPIO_PIN             FixedPcdGet32 (PcdPciePowerGpioPin)
#define PCIE_RESET_GPIO_BANK            FixedPcdGet32 (PcdPcieResetGpioBank)
#define PCIE_RESET_GPIO_PIN             FixedPcdGet32 (PcdPcieResetGpioPin)
#define PCIE_LINK_SPEED                 FixedPcdGet32 (PcdPcieLinkSpeed)

STATIC
VOID
PciSetupClocks (
  VOID
  )
{
  CruDeassertSoftReset (10, 1); /* resetn_pcie20_powerup_req */

  CruEnableClock (12, 5); /* clk_pcie20_pipe_en */
  CruEnableClock (12, 4); /* clk_pcie20_aux_en */
  CruEnableClock (12, 3); /* pclk_pcie20_en */
  CruEnableClock (12, 2); /* aclk_pcie20_dbi_en */
  CruEnableClock (12, 1); /* aclk_pcie20_slv_en */
  CruEnableClock (12, 0); /* aclk_pcie20_mst_en */

  /* PCIe 3.0 clocks */
  DEBUG ((DEBUG_INFO, "HACK: Setup PCIe3 Clocks\n"));
  CruDeassertSoftReset (12, 1); /* resetn_pcie30x2_powerup_req */
  CruEnableClock (13, 5); /* clk_pcie30x2_pipe_en */
  CruEnableClock (13, 4); /* clk_pcie30x2_aux_en */
  CruEnableClock (13, 3); /* pclk_pcie30x2_en */
  CruEnableClock (13, 2); /* aclk_pcie30x2_en */
  CruEnableClock (13, 1); /* aclk_pcie30x2_en */
  CruEnableClock (13, 0); /* aclk_pcie30x2_en */
}

STATIC
VOID
PciSetRcMode (
  IN EFI_PHYSICAL_ADDRESS ApbBase
  )
{
  MmioOr32 (ApbBase + PCIE_CLIENT_HOT_RESET_CTRL,
            (APP_LSSTM_ENABLE_ENHANCE << 16) | APP_LSSTM_ENABLE_ENHANCE);
  MmioWrite32 (ApbBase + PCIE_CLIENT_GENERAL_CON,
               (DEVICE_TYPE_MASK << 16) | DEVICE_TYPE_RC);
}

STATIC
VOID
PciSetupBars (
  IN EFI_PHYSICAL_ADDRESS DbiBase
  )
{
  DEBUG ((DEBUG_INFO, "PCIe: SetupBars: Unlock DBI RO regs at 0x%lX\n", DbiBase));

  /* Allow writing RO registers through the DBI */
  MmioOr32 (DbiBase + PL_MISC_CONTROL_1_OFF, DBI_RO_WR_EN);

  MmioWrite16 (DbiBase + PCI_DEVICE_CLASS, (PCI_CLASS_BRIDGE << 8) | PCI_CLASS_BRIDGE_P2P);

  DEBUG ((DEBUG_INFO, "PCIe: SetupBars: Speed change\n"));
  /* Initiate a speed change to Gen2 or Gen3 after the link is initialized as Gen1 speed. */
  MmioOr32 (DbiBase + PL_GEN2_CTRL_OFF, DIRECT_SPEED_CHANGE);

  DEBUG ((DEBUG_INFO, "PCIe: SetupBars: Lock DBI RO regs\n"));
  /* Disallow writing RO registers through the DBI */
  MmioAnd32 (DbiBase + PL_MISC_CONTROL_1_OFF, ~DBI_RO_WR_EN);
}

STATIC
VOID
PciSetupLinkSpeed (
  IN EFI_PHYSICAL_ADDRESS DbiBase,
  IN UINT32 Speed
  )
{
  /* Allow writing RO registers through the DBI */
  MmioOr32 (DbiBase + PL_MISC_CONTROL_1_OFF, DBI_RO_WR_EN);

  /* Select target link speed */
  MmioAndThenOr32 (DbiBase + PCIE_LINK_CAPABILITY, ~0xFU, Speed);
  MmioAndThenOr32 (DbiBase + PCIE_LINK_CTL_2, ~0xFU, Speed);

  /* Disallow writing RO registers through the DBI */
  MmioAnd32 (DbiBase + PL_MISC_CONTROL_1_OFF, ~DBI_RO_WR_EN);
}

STATIC
VOID
PciGetLinkSpeedWidth (
  IN EFI_PHYSICAL_ADDRESS DbiBase,
  OUT UINT32 *Speed,
  OUT UINT32 *Width
  )
{
  UINT32 Val;

  Val = MmioRead32 (DbiBase + PCIE_LINK_STATUS);
  *Speed = (Val & LINK_STATUS_SPEED_MASK) >> LINK_STATUS_SPEED_SHIFT;
  *Width = (Val & LINK_STATUS_WIDTH_MASK) >> LINK_STATUS_WIDTH_SHIFT;
}

STATIC
VOID
PciPrintLinkSpeedWidth (
  IN UINT32 Speed,
  IN UINT32 Width
  )
{
  char LinkSpeedBuf[6];

  switch (Speed) {
  case 0:
    AsciiStrCpyS (LinkSpeedBuf, sizeof (LinkSpeedBuf) - 1, "1.25");
    break;
  case 1:
    AsciiStrCpyS (LinkSpeedBuf, sizeof (LinkSpeedBuf) - 1, "2.5");
    break;
  case 2:
    AsciiStrCpyS (LinkSpeedBuf, sizeof (LinkSpeedBuf) - 1, "5.0");
    break;
  case 3:
    AsciiStrCpyS (LinkSpeedBuf, sizeof (LinkSpeedBuf) - 1, "8.0");
    break;
  case 4:
    AsciiStrCpyS (LinkSpeedBuf, sizeof (LinkSpeedBuf) - 1, "16.0");
    break;
  default:
    AsciiSPrint (LinkSpeedBuf, sizeof (LinkSpeedBuf), "%u.%u",
                   (Speed * 25) / 10, (Speed * 25) % 10);
    break;
  }
  DEBUG ((DEBUG_INFO, "PCIe: Link up (x%u, %a GT/s)\n", Width, LinkSpeedBuf));
}

STATIC
VOID
PciEnableLtssm (
  IN EFI_PHYSICAL_ADDRESS ApbBase,
  IN BOOLEAN Enable
  )
{
  UINT32 Val;

  Val = (LINK_REQ_RST_GRT | LTSSM_ENABLE) << 16;
  Val |= LINK_REQ_RST_GRT;
  if (Enable) {
    Val |= LTSSM_ENABLE;
  }
  MmioWrite32 (ApbBase + PCIE_CLIENT_GENERAL_CON, Val);
}

STATIC
BOOLEAN
PciIsLinkUp (
  IN EFI_PHYSICAL_ADDRESS ApbBase
  )
{
  STATIC UINT32 LastVal = 0xFFFFFFFF;
  UINT32 Val;

  Val = MmioRead32 (ApbBase + PCIE_CLIENT_LTSSM_STATUS);
  if (Val != LastVal) {
    DEBUG ((DEBUG_INFO, "PCIe: PciIsLinkUp(): LTSSM_STATUS=0x%08X\n", Val));
    LastVal = Val;
  }

  if ((Val & RDLH_LINK_UP) == 0) {
    return FALSE;
  }
  if ((Val & SMLH_LINK_UP) == 0) {
    return FALSE;
  }

  return (Val & SMLH_LTSSM_STATE_MASK) == SMLH_LTSSM_STATE_LINK_UP;
}

STATIC
VOID
PciSetupAtu (
  IN EFI_PHYSICAL_ADDRESS DbiBase,
  IN UINT32 Index,
  IN UINT32 Type,
  IN UINT64 CpuBase,
  IN UINT64 BusBase,
  IN UINT64 Length
  )
{
  UINT32 Ctrl2Off = IATU_ENABLE;

  if (Type == IATU_TYPE_CFG0 || Type == IATU_TYPE_CFG1) {
    Ctrl2Off |= IATU_CFG_SHIFT_MODE;
  }

  MmioWrite32 (DbiBase + IATU_REGION_CTRL_OUTBOUND (Index) + IATU_LWR_BASE_ADDR_OFF,
               (UINT32)CpuBase);
  MmioWrite32 (DbiBase + IATU_REGION_CTRL_OUTBOUND (Index) + IATU_UPPER_BASE_ADDR_OFF,
               (UINT32)(CpuBase >> 32));
  MmioWrite32 (DbiBase + IATU_REGION_CTRL_OUTBOUND (Index) + IATU_LIMIT_ADDR_OFF,
               (UINT32)(CpuBase + Length - 1));
  MmioWrite32 (DbiBase + IATU_REGION_CTRL_OUTBOUND (Index) + IATU_LWR_TARGET_ADDR_OFF,
               (UINT32)BusBase);
  MmioWrite32 (DbiBase + IATU_REGION_CTRL_OUTBOUND (Index) + IATU_UPPER_TARGET_ADDR_OFF,
               (UINT32)(BusBase >> 32));
  MmioWrite32 (DbiBase + IATU_REGION_CTRL_OUTBOUND (Index) + IATU_REGION_CTRL_1_OFF,
               Type);
  MmioWrite32 (DbiBase + IATU_REGION_CTRL_OUTBOUND (Index) + IATU_REGION_CTRL_2_OFF,
               Ctrl2Off);

  gBS->Stall (10000);
}

STATIC
VOID
UpdateGrfRegister (
  IN EFI_PHYSICAL_ADDRESS Reg,
  IN UINT32 Mask,
  IN UINT32 Val
  )
{
  MmioWrite32 (Reg, (Mask << 16) | Val);
}

EFI_STATUS
InitializePciHost (
  VOID
  )
{
  EFI_PHYSICAL_ADDRESS     ApbBase = PCIE2X1_APB_BASE;
  EFI_PHYSICAL_ADDRESS     DbiBase = PCIE2X1_DBI_BASE;
  // EFI_PHYSICAL_ADDRESS     ApbBase = PCIE3X2_APB_BASE;
  // EFI_PHYSICAL_ADDRESS     DbiBase = PCIE3X2_DBI_BASE;

  UINTN                    Retry;
  UINT32                   LinkSpeed;
  UINT32                   LinkWidth;
  UINT64                   Cfg0Base;
  UINT64                   Cfg0Size;
  UINT64                   Cfg1Base;
  UINT64                   Cfg1Size;
  UINT64                   PciIoBase;
  UINT64                   PciIoSize;
  EFI_PHYSICAL_ADDRESS Pcie30PhyGrfBaseAddr = PCIE30_PHY_GRF;

  /* Configure MULTI-PHY */
  CruSetPciePhySource (2, 0);
  MultiPhySetMode (2, MULTIPHY_MODE_PCIE);

  /* Initialize rk3568-pcie3-phy */
  DEBUG ((DEBUG_INFO, "HACK: Initialize rk3568-pcie3-phy\n"));
  DEBUG ((DEBUG_INFO, "GOD BigfootACA\n"));
  DEBUG ((DEBUG_INFO, "Enabling PCIe related clocks\n"));
  PmuCruEnableClock (2, 13); /* clk_pcie30phy_ref_m_en */
  PmuCruEnableClock (2, 14); /* clk_pcie30phy_ref_n_en */
  CruEnableClock (33, 8); /* pclk_pcie30phy_en */
  DEBUG ((DEBUG_INFO, "Assert Reset!\n"));
  CruAssertSoftReset (27, 14); /* resetn_pcie20_powerup_req */
  gBS->Stall (1000); 

  /* Deassert PCIe PMA output clamp mode */
  UpdateGrfRegister (Pcie30PhyGrfBaseAddr + 0x0024, 0xFFFF,
                      (0x1 << 15) | (0x1 << 31));
  /* Set bifurcation */         
  DEBUG ((DEBUG_INFO, "Set bifurcation!\n"));           
  UpdateGrfRegister (Pcie30PhyGrfBaseAddr + 0x0018, 0xFFFF,
                      0x1 | (0xf << 16));
  UpdateGrfRegister (Pcie30PhyGrfBaseAddr + 0x0004, 0xFFFF,
                      (0x1 << 15) | (0x1 << 31));

  CruDeassertSoftReset (27, 14); /* resetn_pcie20_powerup_req */
  gBS->Stall (1000); 

  /* Power PCIe */
  DEBUG ((DEBUG_INFO, "PCIe: Powering up by setting GPIO pins!\n"));
  if (PCIE_POWER_GPIO_BANK != 0xFFFFFFFFU) {
    GpioPinSetDirection (PCIE_POWER_GPIO_BANK, PCIE_POWER_GPIO_PIN, GPIO_PIN_OUTPUT);
    GpioPinWrite (PCIE_POWER_GPIO_BANK, PCIE_POWER_GPIO_PIN, TRUE);
    gBS->Stall (100000);
  }

  DEBUG ((DEBUG_INFO, "PCIe: Setup clocks\n"));
  PciSetupClocks ();
  DEBUG ((DEBUG_INFO, "PCIe: Switching to RC mode\n"));
  PciSetRcMode (ApbBase);
  DEBUG ((DEBUG_INFO, "PCIe: Setup BARs\n"));
  PciSetupBars (DbiBase);
  DEBUG ((DEBUG_INFO, "PCIe: Set link speed\n"));
  PciSetupLinkSpeed (DbiBase, PCIE_LINK_SPEED);

  DEBUG ((DEBUG_INFO, "PCIe: Reset!\n"));
  if (PCIE_RESET_GPIO_BANK != 0xFFFFFFFFU) {
    ASSERT (PCIE_RESET_GPIO_PIN != 0xFFFFFFFFU);
    GpioPinSetDirection (PCIE_RESET_GPIO_BANK, PCIE_RESET_GPIO_PIN, GPIO_PIN_OUTPUT);
    GpioPinWrite (PCIE_RESET_GPIO_BANK, PCIE_RESET_GPIO_PIN, 0);
    gBS->Stall (1000000);
    GpioPinWrite (PCIE_RESET_GPIO_BANK, PCIE_RESET_GPIO_PIN, 1);
  }

  DEBUG ((DEBUG_INFO, "PCIe: Setup iATU\n"));
  Cfg0Base = SIZE_1MB;
  Cfg0Size = SIZE_64KB;
  Cfg1Base = SIZE_2MB;
  Cfg1Size = 0x10000000UL - (SIZE_2MB + SIZE_64KB);
  PciIoBase = 0x2FFF0000UL;
  PciIoSize = SIZE_64KB;

  // PciSetupAtu (DbiBase, 0, IATU_TYPE_CFG0, 0x300000000UL + Cfg0Base, Cfg0Base, Cfg0Size);
  // PciSetupAtu (DbiBase, 1, IATU_TYPE_CFG1, 0x300000000UL + Cfg1Base, Cfg1Base, Cfg1Size);

  PciSetupAtu (DbiBase, 0, IATU_TYPE_CFG0, 0x380000000UL + Cfg0Base, Cfg0Base, Cfg0Size);
  PciSetupAtu (DbiBase, 1, IATU_TYPE_CFG1, 0x380000000UL + Cfg1Base, Cfg1Base, Cfg1Size);
  PciSetupAtu (DbiBase, 2, IATU_TYPE_IO,   0x380000000UL + PciIoBase, 0, PciIoSize);

  DEBUG ((DEBUG_INFO, "PCIe: Start LTSSM!\n"));
  PciEnableLtssm (ApbBase, FALSE);
  MmioWrite32 (ApbBase + PCIE_CLIENT_GENERAL_DEBUG_INFO, 0);
  PciEnableLtssm (ApbBase, TRUE);

  /* Wait for link up */
  DEBUG ((DEBUG_INFO, "PCIe: Waiting for link up...\n"));
  for (Retry = 20; Retry != 0; Retry--) {
    if (PciIsLinkUp (ApbBase)) {
      break;
    }
    gBS->Stall (100000);
  }
  if (Retry == 0) {
    DEBUG ((DEBUG_WARN, "PCIe: Link up timeout!\n"));
    return EFI_TIMEOUT;
  }

  DEBUG ((DEBUG_INFO, "PCIe: The Fucking Link is up!!!!!\n"));
  PciGetLinkSpeedWidth (DbiBase, &LinkSpeed, &LinkWidth);
  PciPrintLinkSpeedWidth (LinkSpeed, LinkWidth);

  return EFI_SUCCESS;
}