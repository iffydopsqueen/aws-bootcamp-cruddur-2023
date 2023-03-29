from datetime import datetime, timedelta, timezone
from opentelemetry import trace
from lib.db import db

# Connection pooling for our DB
# from lib.db import pool, query_wrap_array

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

      sql = db.template('activities','home')
      results = db.query_array_json(sql)
      return results