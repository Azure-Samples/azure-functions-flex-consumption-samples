using System;
using System.ComponentModel;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;

namespace flexconsumptionloadwithvnetdemo
{
    class Program
    {
        static async Task Main(string[] args)
        {
            var host = new HostBuilder()
                .ConfigureFunctionsWorkerDefaults()
                .Build();
            await host.RunAsync();
        }
    }
}