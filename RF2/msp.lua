local mspApiVersion =
{
    command = 1, -- MSP_API_VERSION
    processReply = function(s, buf)
        if #buf >= 3 then
            rf2.fc.apiVersion = buf[2] + buf[3] / 100
            print(rf2.fc.apiVersion)
            return true
        end
        return false
    end,
    exampleResponse = { 1, { 0, 12, 6 }, nil}
}

local mspAccCalibration =
{
    command = 205, -- MSP_ACC_CALIBRATION
    processReply = function(s, buf)
        print("Calibrated!")
        return true
    end,
    exampleResponse = { 205, nil, nil}
}

local MspMessageController = {}

function MspMessageController.new()
    local self = {
        messageQueue = {},
        currentMessage = nil,
        lastRunTS = 0,
        messages = {
            MSP_API_VERSION = mspApiVersion,
            MSP_ACC_CALIBRATION = mspAccCalibration
        }
    }

    function self:isReady(value)
        if not self.currentMessage and #self.messageQueue == 0 then
            return true
        end

        if not self.currentMessage then
            self.currentMessage = table.remove(self.messageQueue, 1)
        end

        if self.lastRunTS == 0 or self.lastRunTS + 50 < rf2.getTime() then
            rf2.protocol.mspRead(self.currentMessage.command)
            self.lastRunTS = getTime()
        end

        mspProcessTxQ()
        local cmd, buf, err = mspPollReply()

        --[[
        local returnExampleTuple = function(table) return table[1], table[2], table[3] end
        local cmd, buf, err = returnExampleTuple(self.currentMessage.exampleResponse)
        --]]

        if cmd == self.currentMessage.command and not err then
            if self.currentMessage.processReply(self.currentMessage, buf) then
                self.currentMessage = nil
            end
        end

        return false
    end

    function self:add(message)
        table.insert(self.messageQueue, self.messages[message])
        return self
    end

    function self:addCustom(message)
        table.insert(self.messageQueue, message)
        return self
    end

    return self
end

return MspMessageController.new()

--[[
local mspCustom =
{
    command = 111, --
    processReply = function(s, buf)
        print("Custom!")
        return true
    end,
    exampleResponse = { 111, nil, nil}
}


local mmc = MspMessageController.new()
mmc
  :add("MSP_API_VERSION")
  :add("MSP_ACC_CALIBRATION")
  :addCustom(mspCustom)

while mmc:processMessageQueue() do end
--]]

