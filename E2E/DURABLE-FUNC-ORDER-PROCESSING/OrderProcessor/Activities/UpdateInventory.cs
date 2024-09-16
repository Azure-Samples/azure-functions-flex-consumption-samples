using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Company.Function.Models;

namespace Company.Function.Activities
{
    public static class UpdateInventory{
        [Function(nameof(UpdateInventory))]
        public static async Task<object?> RunAsync([ActivityTrigger] PaymentRequest req, 
        FunctionContext executionContext)
        {
            ILogger logger = executionContext.GetLogger("UpdateInventory");
            logger.LogInformation( "Reserving inventory for order {requestId} of {quantity} {name}",
                req.RequestId,
                req.Amount,
                req.ItemBeingPurchased);

            // In a real app, this would be a call to a database or external service to update inventory
            // For simplicity, we pretend the inventory has been updated and log the new quantity
            await Task.Delay(TimeSpan.FromSeconds(5));    
            logger.LogInformation($"There are now: 100 {req.ItemBeingPurchased} left in stock");
           
            return null;
        }
       
    }
     
}
