using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Company.Function.Models;

namespace Company.Function.Activities
{
    public static class ReserveInventory{
        [Function(nameof(ReserveInventory))]
        public static async Task<InventoryResult> RunAsync([ActivityTrigger] InventoryRequest req, 
        FunctionContext executionContext)
        {
            ILogger logger = executionContext.GetLogger("ReserveInventory");
            logger.LogInformation( "Reserving inventory for order {requestId} of {quantity} {name}",
                req.RequestId,
                req.Quantity,
                req.ItemName);
            
            // In a real app, this would be a call to a database or external service to check inventory
            // For simplicity, we'll just return a successful result with a dummy OrderPayload
            var pretendDBCall = Task.Delay(TimeSpan.FromSeconds(5));
            await pretendDBCall; // dummy delay to simulate a database call
            OrderPayload orderResponse = new OrderPayload(req.ItemName, TotalCost: 100, req.Quantity);
           
            return new InventoryResult(true, orderResponse);
        }
    }
     
}
