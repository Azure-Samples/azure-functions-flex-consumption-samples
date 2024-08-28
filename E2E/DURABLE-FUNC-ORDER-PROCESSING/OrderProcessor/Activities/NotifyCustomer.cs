using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Company.Function.Models;

namespace Company.Function.Activities
{
    public static class NotifyCustomer{
        [Function(nameof(NotifyCustomer))]
        public static async Task<object?> RunAsync([ActivityTrigger] Notification notification, 
        FunctionContext executionContext)
        {
            ILogger logger = executionContext.GetLogger("NotifyCustomer");
            logger.LogInformation(notification.Message);

            // Simulate async call sending notification
            await Task.Delay(TimeSpan.FromSeconds(5));
           
            return null;
        }
    }
     
}