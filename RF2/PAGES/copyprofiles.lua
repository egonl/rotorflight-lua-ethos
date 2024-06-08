local template = assert(rf2.loadScript(rf2.radio.template))()
local margin = template.margin
local indent = template.indent
local lineSpacing = template.lineSpacing
local tableSpacing = template.tableSpacing
local sp = template.listSpacing.field
local yMinLim = rf2.radio.yMinLimit
local x = margin
local y = yMinLim - lineSpacing
local inc = { x = function(val) x = x + val return x end, y = function(val) y = y + val return y end }
local labels = {}
local fields = {}

fields[#fields + 1] = { t = "Profile type",                x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 1, vals = { 1 }, table = { [0] = "PID", "Rate" } }
fields[#fields + 1] = { t = "Source profile",              x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 5, vals = { 3 }, table = { [0] = "1", "2", "3", "4", "5", "6" } }
fields[#fields + 1] = { t = "Dest. profile",               x = x, y = inc.y(lineSpacing), sp = x + sp, min = 0, max = 5, vals = { 2 }, table = { [0] = "1", "2", "3", "4", "5", "6" } }
labels[#labels + 1] = { t = "Use Save to copy the source", x = x, y = inc.y(lineSpacing) }
labels[#labels + 1] = { t = "profile to the destination.", x = x, y = inc.y(lineSpacing) }

return {
    read        = nil,
    write       = 183, -- MSP_COPY_PROFILE
    reboot      = false,
    eepromWrite = true,
    title       = "Copy",
    minBytes    = 3,
    labels      = labels,
    fields      = fields,
    prepare = function(self)
        rf2.mspQueue:add("MSP_STATUS", self.onProcessedMspStatus, self)
    end,
    onProcessedMspStatus = function(self)
        -- prepare page for MSP_COPY_PROFILE
        self.values = { 0, self.getDestinationPidProfile(self), rf2.FC.CONFIG.profile }
        rf2.dataBindFields()
    end,
    getDestinationPidProfile = function(self)
        local destPidProfile
        if (rf2.FC.CONFIG.profile < rf2.FC.CONFIG.numProfiles - 1) then
            destPidProfile = rf2.FC.CONFIG.profile + 1
        else
            destPidProfile = rf2.FC.CONFIG.profile - 1
        end
        return destPidProfile
    end,
}
