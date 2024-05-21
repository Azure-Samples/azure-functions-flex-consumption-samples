using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace PerfTestEPWin
{
    public static class LoaderIO
    {
        //This is required in case you are load testing this sample using Loader.io
        [Function("LoaderIO")]
        public static HttpResponseData Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "{route}")] HttpRequestData req,
            string route)
        {
            var response = req.CreateResponse(HttpStatusCode.OK);
            response.WriteString(route);
            return response;
        }
    }
}
