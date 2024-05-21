using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Threading.Tasks;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace flexconsumptionloadwithvnetdemo
{
    public class ProcessCustomerFeedback
    {
        [Function("ProcessCustomerFeedback")]
        public async Task<OutputType> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "api/ProcessCustomerFeedback")] HttpRequestData req)
        {
            _logger.LogInformation("Processing new customer feedback.");
            string body = await new StreamReader(req.Body).ReadToEndAsync();

            //Add any processing of the feedback here

            //Sends a 200 response back, and uses output bindings to send the body to event hubs
            return new OutputType()
            {
                OutputEvent = body,
                HttpResponse = req.CreateResponse(HttpStatusCode.OK)
            };
        }
        private readonly ILogger<ProcessCustomerFeedback> _logger;

        public ProcessCustomerFeedback(ILogger<ProcessCustomerFeedback> logger)
        {
            _logger = logger;
        }    
    }

    public class OutputType
    {
        [EventHubOutput("%EventHubName%", Connection = "EventHubConnection")]
        public string OutputEvent { get; set; }

        public HttpResponseData HttpResponse { get; set; }
    }
}
