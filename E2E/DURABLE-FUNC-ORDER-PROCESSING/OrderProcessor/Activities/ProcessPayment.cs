using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Company.Function.Models;

namespace Company.Function.Activities
{
    public static class ProcessPayment{
        [Function(nameof(ProcessPayment))]
        public static async Task<object?> RunAsync([ActivityTrigger] PaymentRequest req, 
        FunctionContext executionContext)
        {
            ILogger logger = executionContext.GetLogger("ProcessPayment");
            logger.LogInformation("Processing payment: {requestId} for {amount} {item} at ${currency}",
                req.RequestId,
                req.Amount,
                req.ItemBeingPurchased,
                req.Currency);

            // Simulate slow processing
            await Task.Delay(TimeSpan.FromSeconds(7));    

            logger.LogInformation("Payment for request ID '{requestId}' processed successfully", req.RequestId);        
           
            return null;
        }
    }  
}
