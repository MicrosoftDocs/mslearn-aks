using System;
namespace drone_webapp.Data {
	public class DroneMetrics {
		readonly Random random = new Random (Guid.NewGuid ().GetHashCode ());
		readonly int windSpeed = 0;
		readonly StatusEnum status = 0;

		public DroneMetrics () {
			windSpeed = random.Next (20);
		}

		public DateTime Date { get; set; }

		public int TemperatureC { get; set; }

		public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);

		public int WindSpeed => windSpeed;

		public StatusEnum Status => status;

		public string Summary { get; set; }

		public enum StatusEnum {
			Ok = 0,
			StrongWind = 1,
			Delayed = 2,
			Grounded = 9
		}
	}
}
