local function readU32(buf, offset)
    local value = 0
    for i = 0, 3 do
        value = value | buf[offset + i] << (i * 8)
    end
    return value
end

local mspApiVersion =
{
    command = 1, -- MSP_API_VERSION
    processReply = function(self, buf)
        if #buf >= 3 then
            rf2.FC.CONFIG.apiVersion = buf[2] + buf[3] / 100
            print("API version: "..rf2.FC.CONFIG.apiVersion)
        end
    end,
    --exampleResponse = { 1, { 0, 12, 6 }, nil}
}

local mspStatus =
{
    command = 101, -- MSP_STATUS
    processReply = function(self, buf)
        rf2.FC.CONFIG.armingDisableFlags = readU32(buf, 18)
        print("Arming disable flags: "..tostring(rf2.FC.CONFIG.armingDisableFlags))
        rf2.FC.CONFIG.profile = buf[24]
        rf2.FC.CONFIG.numProfiles = buf[25]
        rf2.FC.CONFIG.rateProfile = buf[26]
        rf2.FC.CONFIG.numRateProfiles = buf[27]
        rf2.FC.CONFIG.motorCount = buf[28]
        print("Number of motors: "..tostring(rf2.FC.CONFIG.motorCount))
        rf2.FC.CONFIG.servoCount = buf[29]
        print("Number of servos: "..tostring(rf2.FC.CONFIG.servoCount))
    end,
}

local mspAccCalibration =
{
    command = 205, -- MSP_ACC_CALIBRATION
    processReply = function(self, buf)
        print("Calibrated!")
    end,
    --exampleResponse = { 205, nil, nil}
}

-- MspQueueController class
local MspQueueController = {}
MspQueueController.__index = MspQueueController

function MspQueueController.new()
    local self = setmetatable({}, MspQueueController)
    self.messageQueue = {}
    self.currentMessage = nil
    self.lastTimeCommandSent = 0
    self.retryCount = 0
    self.maxRetries = 3
    self.messages = {
        MSP_API_VERSION = mspApiVersion,
        MSP_STATUS = mspStatus,
        MSP_ACC_CALIBRATION = mspAccCalibration,
    }
    return self
end

function MspQueueController:isProcessed()
    return not self.currentMessage and #self.messageQueue == 0
end

function MspQueueController:processQueue()
    if self:isProcessed() then
        return
    end

    if not self.currentMessage then
        self.currentMessage = table.remove(self.messageQueue, 1)
        self.retryCount = 0
    end

    if self.lastTimeCommandSent == 0 or self.lastTimeCommandSent + 50 < rf2.getTime() then
        if self.currentMessage.payload then
            rf2.protocol.mspWrite(self.currentMessage.command, self.currentMessage.payload)
        else
            rf2.protocol.mspWrite(self.currentMessage.command, {})
        end
        self.lastTimeCommandSent = getTime()
        self.retryCount = self.retryCount + 1
    end

    mspProcessTxQ()
    local cmd, buf, err = mspPollReply()

    --[[
    local returnExampleTuple = function(table) return table[1], table[2], table[3] end
    local cmd, buf, err = returnExampleTuple(self.currentMessage.exampleResponse)
    --]]

    -- 68 = MSP_REBOOT
    if (cmd == self.currentMessage.command and not err) or (self.currentMessage.command == 68 and self.retryCount == 2) then
        if self.currentMessage.processReply then
            self.currentMessage:processReply(buf)
        end
        if self.currentMessage.onProcessed then
            self.currentMessage.onProcessed(self.currentMessage.onProcessedParameter)
        end
        self.currentMessage = nil
    elseif self.retryCount == self.maxRetries then
        self.currentMessage = nil
    end
end

-- onProcessed and onProcessedParameter are optional parameters
function MspQueueController:add(message, onProcessed, onProcessedParameter)
    if onProcessed then
        self.messages[message].onProcessed = onProcessed
        self.messages[message].onProcessedParameter = onProcessedParameter
    end
    table.insert(self.messageQueue, self.messages[message])
    return self
end

function MspQueueController:addCustomMessage(message)
    table.insert(self.messageQueue, message)
    return self
end

return MspQueueController.new()

-- Usage example

--[[
local mspCustom =
{
    command = 111,
    processReply = nil,
    onProcessed = function(self, buf)
        print("Do something with the response!")
    end,
    exampleResponse = { 111, nil, nil}
}

local myMspQueue = MspQueueController.new()
myMspQueue
  :add("MSP_API_VERSION")
  :add("MSP_ACC_CALIBRATION")
  :addCustomMessage(mspCustom)

while not myMspQueue:isProcessed() do
    myMspQueue:processQueue()
end
--]]