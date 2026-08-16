#include <Arduino.h>
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>

#define PANEL_RES_X 64
#define PANEL_RES_Y 32
#define PANEL_CHAIN 4
#define LED_WIDTH 256
#define LED_HEIGHT 32

MatrixPanel_I2S_DMA *dma_display = nullptr;

uint8_t bitmapData[8192]; 
int imgWidth = 0, displayMode = 0, bytesPerRow = 0;
int shortMode = 0, longMode = 0;
uint16_t imgColor = 0xFFFF;

float xPos = 0, yPos = 0, targetX = 0, targetY = 0, moveStepX = 0, moveStepY = 0;
float scrollSpeed = 1.0;
unsigned long stayMs = 1000, stateStartTime = 0;
float entryDur = 500;

enum State { ENTERING, STAYING, SCROLLING, FINISHED };
State currentState = FINISHED;

uint8_t h2b(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return 0;
}

void parseImage(String cmd) {
    uint8_t brightness = strtoul(cmd.substring(2, 4).c_str(), NULL, 16);
    if (dma_display) {
        dma_display->setBrightness8(brightness); 
    }

    uint32_t r = strtoul(cmd.substring(4, 6).c_str(), NULL, 16);
    uint32_t g = strtoul(cmd.substring(6, 8).c_str(), NULL, 16);
    uint32_t b = strtoul(cmd.substring(8, 10).c_str(), NULL, 16);
    imgColor = dma_display->color565(r, b, g);
    
    int sIdx = cmd.indexOf("|S:");
    int wIdx = cmd.indexOf("|W:");
    int mIdx = cmd.indexOf("|M:");
    int esIdx = cmd.indexOf("|ES:");
    int elIdx = cmd.indexOf("|EL:");
    int epIdx = cmd.indexOf("|EP:");
    int tIdx = cmd.indexOf("|T:");
    int flIdx = cmd.indexOf("|FL:");
    int dIdx = cmd.indexOf("|D:");

    scrollSpeed = cmd.substring(sIdx + 3, wIdx).toFloat();
    imgWidth = cmd.substring(wIdx + 3, mIdx).toInt();
    displayMode = cmd.substring(mIdx + 3, esIdx).toInt();
    shortMode = cmd.substring(esIdx + 4, elIdx).toInt();
    longMode = cmd.substring(elIdx + 4, epIdx).toInt();
    entryDur = cmd.substring(epIdx + 4, tIdx).toFloat();
    stayMs = cmd.substring(tIdx + 3, flIdx).toInt();
    bytesPerRow = (imgWidth + 7) / 8;

    String hexData = cmd.substring(dIdx + 3);
    int len = hexData.length() / 2;
    memset(bitmapData, 0, sizeof(bitmapData));
    for (int i = 0; i < len; i++) {
        bitmapData[i] = (h2b(hexData[i*2]) << 4) | h2b(hexData[i*2+1]);
    }

    targetX = 0; targetY = 0;
    float startX = 0, startY = 0;

    if (displayMode == 1) {
        targetX = (shortMode % 2 == 1) ? (LED_WIDTH - imgWidth) / 2 : 0;
        targetY = 0;
        if (shortMode <= 1) { startX = targetX; startY = LED_HEIGHT; }
        else if (shortMode <= 3) { startX = targetX; startY = -LED_HEIGHT; }
        else { startX = LED_WIDTH; startY = 0; }
        currentState = ENTERING;
    } else {
        targetX = 0; targetY = 0;
        if (longMode == 0) { startX = 0; startY = LED_HEIGHT; }
        else if (longMode == 1) { startX = 0; startY = -LED_HEIGHT; }
        else if (longMode == 2) { startX = LED_WIDTH; startY = 0; }
        else { startX = LED_WIDTH; startY = 0; currentState = SCROLLING; }
        if (longMode != 3) currentState = ENTERING;
    }

    xPos = startX; yPos = startY;
    float frames = entryDur / 10.0;
    if (frames < 1) frames = 1;
    moveStepX = (targetX - startX) / frames;
    moveStepY = (targetY - startY) / frames;
}

void updateDisplay() {
    dma_display->fillScreen(0); 
    int ix = (int)xPos;
    int iy = (int)yPos;

    for (int vy = 0; vy < LED_HEIGHT; vy++) {
        int py = vy + iy;
        if (py < 0 || py >= LED_HEIGHT) continue;
        uint8_t* rowPtr = &bitmapData[vy * bytesPerRow];
        for (int vx = 0; vx < imgWidth; vx++) {
            int px = vx + ix;
            if (px < 0 || px >= LED_WIDTH) continue;
            if (rowPtr[vx >> 3] & (0x80 >> (vx & 7))) {
                dma_display->drawPixel(px, py, imgColor);
            }
        }
    }
    dma_display->flipDMABuffer();
}

void setup() {
    Serial.begin(115200);
    Serial.setRxBufferSize(20480);
    
    HUB75_I2S_CFG mx(PANEL_RES_X, PANEL_RES_Y, PANEL_CHAIN);
    mx.double_buff = true;
    
    mx.gpio.r1 = 25; mx.gpio.g1 = 26; mx.gpio.b1 = 27;
    mx.gpio.r2 = 14; mx.gpio.g2 = 12; mx.gpio.b2 = 13;
    mx.gpio.a = 23;  mx.gpio.b = 22;  mx.gpio.c = 5;  mx.gpio.d = 17;
    mx.gpio.lat = 4; mx.gpio.oe = 15; mx.gpio.clk = 16;
    
    dma_display = new MatrixPanel_I2S_DMA(mx);
    dma_display->begin();
    dma_display->setBrightness8(128);
    dma_display->clearScreen();
}

void loop() {
    if (Serial.available() > 0) {
        String cmd = Serial.readStringUntil('\n');
        if (cmd.startsWith("I:")) parseImage(cmd);
    }

    if (currentState != FINISHED) {
        if (currentState == ENTERING) {
            bool arrived = true;
            if (abs(targetX - xPos) > abs(moveStepX)) { xPos += moveStepX; arrived = false; } else { xPos = targetX; }
            if (abs(targetY - yPos) > abs(moveStepY)) { yPos += moveStepY; arrived = false; } else { yPos = targetY; }
            updateDisplay();
            if (arrived) { currentState = STAYING; stateStartTime = millis(); }
        } 
        else if (currentState == STAYING) {
            if (millis() - stateStartTime > stayMs) {
                if (displayMode == 0) currentState = SCROLLING;
                else { 
                    currentState = FINISHED; 
                    dma_display->fillScreen(0);
                    dma_display->flipDMABuffer();
                    Serial.println("FIN");
                    Serial.flush();
                }
            }
        } 
        else if (currentState == SCROLLING) {
            xPos -= (scrollSpeed * 0.02); 
            updateDisplay();
            if (xPos < -imgWidth) { 
                currentState = FINISHED; 
                dma_display->fillScreen(0);
                dma_display->flipDMABuffer();
                Serial.println("FIN");
                Serial.flush();
            }
        }
    }
    delay(10); 
}