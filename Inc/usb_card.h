/*
 * USB_CARD.h
 *
 *  Created on: Mar 12, 2017
 *  Author: minht57
 */

#ifndef USB_CARD_H_
#define USB_CARD_H_

#include <stdint.h>
#include "usb_device.h"
#include "usbd_custom_hid_if.h"

extern USBD_HandleTypeDef hUsbDeviceFS;

typedef struct{
	uint8_t		ui8DI[8];
	uint8_t		ui8DO[8];
	uint16_t	ui16AI[2];
	uint16_t	ui16AO[2];
	uint16_t	ui16C[2];
}USB_Card_Data_t;

typedef enum{
	DO = 0,
	AO,
	CR
}USB_Data_Type_t;

uint8_t USBD_CUSTOM_HID_SendReport(USBD_HandleTypeDef  *pdev, uint8_t *report, uint16_t len);

extern void ADC_Read_All(uint16_t* ui16Value);
extern void DAC_Write_Channel(uint16_t ui16Value, uint8_t ui8Channel);
extern void Counter_Read_All(uint16_t* ui16Value);
extern void Counter_Reset(uint8_t ui8Channel);

#endif /* USB_CARD_H_ */
