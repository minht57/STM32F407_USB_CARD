/*
 * MQTT_IR.c
 *
 *  Created on: Mar 12, 2017
 *  Author: minht57
 */
 
#include "usb_card.h"
#include "stm32f4xx.h"
#include "stm32f4xx_hal.h"

USB_Card_Data_t USB_Card_Data;

static uint8_t ui8Buf_Data[64];
static uint8_t ui8Buff_Rec[64];
USB_Data_Type_t USB_Data_Type;

void UC_DI(void){
	USB_Card_Data.ui8DI[0] = HAL_GPIO_ReadPin(GPIOE,GPIO_PIN_5);	//PE5
	USB_Card_Data.ui8DI[1] = HAL_GPIO_ReadPin(GPIOE,GPIO_PIN_3);	//PE3
	USB_Card_Data.ui8DI[2] = HAL_GPIO_ReadPin(GPIOE,GPIO_PIN_1);	//PE1
	USB_Card_Data.ui8DI[3] = HAL_GPIO_ReadPin(GPIOB,GPIO_PIN_9);	//PB9
	USB_Card_Data.ui8DI[4] = HAL_GPIO_ReadPin(GPIOB,GPIO_PIN_7);	//PB7
	USB_Card_Data.ui8DI[5] = HAL_GPIO_ReadPin(GPIOB,GPIO_PIN_5);	//PB5
	USB_Card_Data.ui8DI[6] = HAL_GPIO_ReadPin(GPIOB,GPIO_PIN_3);	//PB3
	USB_Card_Data.ui8DI[7] = HAL_GPIO_ReadPin(GPIOD,GPIO_PIN_6);	//PD6
}

void UC_DO(void){
	//PD4
	if(USB_Card_Data.ui8DO[0] == 0){
		HAL_GPIO_WritePin(GPIOD,GPIO_PIN_4,GPIO_PIN_RESET);
	}
	else{
		HAL_GPIO_WritePin(GPIOD,GPIO_PIN_4,GPIO_PIN_SET);
	}
	//PD2
	if(USB_Card_Data.ui8DO[1] == 0){
		HAL_GPIO_WritePin(GPIOD,GPIO_PIN_2,GPIO_PIN_RESET);
	}
	else{
		HAL_GPIO_WritePin(GPIOD,GPIO_PIN_2,GPIO_PIN_SET);
	}
	//PD0
	if(USB_Card_Data.ui8DO[2] == 0){
		HAL_GPIO_WritePin(GPIOD,GPIO_PIN_0,GPIO_PIN_RESET);
	}
	else{
		HAL_GPIO_WritePin(GPIOD,GPIO_PIN_0,GPIO_PIN_SET);
	}
	//PC11
	if(USB_Card_Data.ui8DO[3] == 0){
		HAL_GPIO_WritePin(GPIOC,GPIO_PIN_11,GPIO_PIN_RESET);
	}
	else{
		HAL_GPIO_WritePin(GPIOC,GPIO_PIN_11,GPIO_PIN_SET);
	}
	//PA15
	if(USB_Card_Data.ui8DO[4] == 0){
		HAL_GPIO_WritePin(GPIOA,GPIO_PIN_15,GPIO_PIN_RESET);
	}
	else{
		HAL_GPIO_WritePin(GPIOA,GPIO_PIN_15,GPIO_PIN_SET);
	}
	//PA9
	if(USB_Card_Data.ui8DO[5] == 0){
		HAL_GPIO_WritePin(GPIOA,GPIO_PIN_9,GPIO_PIN_RESET);
	}
	else{
		HAL_GPIO_WritePin(GPIOA,GPIO_PIN_9,GPIO_PIN_SET);
	}
	//PC9
	if(USB_Card_Data.ui8DO[6] == 0){
		HAL_GPIO_WritePin(GPIOC,GPIO_PIN_9,GPIO_PIN_RESET);
	}
	else{
		HAL_GPIO_WritePin(GPIOC,GPIO_PIN_9,GPIO_PIN_SET);
	}
	//PC7
	if(USB_Card_Data.ui8DO[7] == 0){
		HAL_GPIO_WritePin(GPIOC,GPIO_PIN_7,GPIO_PIN_RESET);
	}
	else{
		HAL_GPIO_WritePin(GPIOC,GPIO_PIN_7,GPIO_PIN_SET);
	}
}

void UC_AI(void){
	ADC_Read_All(USB_Card_Data.ui16AI);//0-PA0; 1-PA1
}

void UC_AO(void){
	DAC_Write_Channel(USB_Card_Data.ui16AO[0],1);	//PA4
	DAC_Write_Channel(USB_Card_Data.ui16AO[1],2);	//PA5
}

void UC_C(void){
	Counter_Read_All(USB_Card_Data.ui16C);//0-PA7; 1-PB15
}

void Loop_Cycle(void){
	HAL_GPIO_TogglePin(GPIOD,GPIO_PIN_13);
	UC_DI();
	UC_AI();
	UC_C();
	uint8_t ui8Len;
	ui8Len = snprintf((char*)ui8Buf_Data,64,"DI,%d,%d,%d,%d,%d,%d,%d,%d,AI,%d,%d,C,%d,%d",
			USB_Card_Data.ui8DI[0],USB_Card_Data.ui8DI[1],USB_Card_Data.ui8DI[2],USB_Card_Data.ui8DI[3],USB_Card_Data.ui8DI[4],USB_Card_Data.ui8DI[5],USB_Card_Data.ui8DI[6],USB_Card_Data.ui8DI[7],
			USB_Card_Data.ui16AI[0],USB_Card_Data.ui16AI[1],USB_Card_Data.ui16C[0],USB_Card_Data.ui16C[1]);
	USBD_CUSTOM_HID_SendReport(&hUsbDeviceFS,ui8Buf_Data,ui8Len);
}

void USB_RX_Interrupt(void){
	HAL_GPIO_TogglePin(GPIOD,GPIO_PIN_14);
	USBD_CUSTOM_HID_HandleTypeDef *myusb=(USBD_CUSTOM_HID_HandleTypeDef *)hUsbDeviceFS.pClassData;
	uint8_t ui8idx;
	for(ui8idx = 0; ui8idx < myusb->Report_buf[0]; ui8idx++){
		ui8Buff_Rec[ui8idx] = myusb->Report_buf[ui8idx+1];
	}
	char* cToken;
	cToken = strtok((char*)ui8Buff_Rec,",");
	while(cToken != NULL){
		if(strcmp(cToken,"DO")==0){
			USB_Data_Type = DO;
			ui8idx = 0;
		}
		else if(strcmp(cToken,"AO")==0){
			USB_Data_Type = AO;
			ui8idx = 0;
		}
		else if(strcmp(cToken,"CR")==0){
			USB_Data_Type = CR;
		}
		else if(USB_Data_Type == DO){
			if(atoi(cToken) < 2)
				USB_Card_Data.ui8DO[ui8idx++] = atoi(cToken);
			ui8idx %= 8;
		}
		else if(USB_Data_Type == AO){
			if(atoi(cToken) < 4096)
				USB_Card_Data.ui16AO[ui8idx++] = atoi(cToken);
			ui8idx %= 2;
		}
		else if(USB_Data_Type == CR){
			uint8_t ui8CounterChannel;
			ui8CounterChannel = atoi(cToken);
			if(ui8CounterChannel < 2){
				Counter_Reset(ui8CounterChannel);
			}
		}
		cToken = strtok(NULL,",");
	}
	UC_DO();
	UC_AO();
}
