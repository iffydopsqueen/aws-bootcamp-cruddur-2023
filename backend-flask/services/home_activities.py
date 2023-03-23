from datetime import datetime, timedelta, timezone
from opentelemetry import trace

# Connection pooling for our DB
from lib.db import pool, query_wrap_array

tracer = trace.get_tracer("home.activities")

class HomeActivities:
  def run(cognito_user_id=None):
  
  # CloudWatch Logs
  # def run(logger):
    # logger.info("HomeActivities")
    # create a span
    with tracer.start_as_current_span("home-activities-mock-data"):
      span = trace.get_current_span()

      # add an attribute 
      now = datetime.now(timezone.utc).astimezone()
      span.set_attribute("app.now", now.isoformat())

      sql = query_wrap_array("""
      SELECT * FROM public.activities
      """)
      print(sql)

      with pool.connection() as conn:
        with conn.cursor() as cur:
          cur.execute(sql)
          # this will return a tuple
          # the first field being the data
          json = cur.fetchone()
      print("45-----------")
      return json[0]

      return results