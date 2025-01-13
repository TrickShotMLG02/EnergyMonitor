-- EnergyTransfer Base Class
local EnergyTransfer = {
    name = "",
    id = {},
    type = "",
    transferType = "", -- "input", "output", or "both"
    status = "",

    -- Basic Methods
    transferRateInput = function(self)
        if transferType == _G.TransferType.Input or transferType == _G.TransferType.Both then
            return self.id.getTransferRateInput() -- Assuming this method exists
        else
            return 0
        end
    end,

    transferRateOutput = function(self)
        if transferType == _G.TransferType.Output or transferType == _G.TransferType.Both then
            return self.id.getTransferRateOutput() -- Assuming this method exists
        else
            return 0
        end
    end
}

function _G.newEnergyTransfer(name, id, side, type, transferType)
    local transfer = {}
    setmetatable(transfer, {__index = EnergyTransfer})
    
    transfer.name = name
    transfer.id = id
    transfer.side = side
    transfer.type = type
    transfer.transferType = transferType

    return transfer
end

function _G.printEnergyTransferData(transfer)
    print("Name: "..transfer.name)
    print("ID: "..tostring(transfer.id))
    -- print("Status: "..transfer:status())
    print("TransferType: " ..transfer.transferType)
    print("Input: "..transfer:transferRateInput())
    print("Output: "..transfer:transferRateOutput())
end