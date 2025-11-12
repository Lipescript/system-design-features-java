package br.com.lipescript.service;

public class TimeConstants {

  private TimeConstants() {}

  public static final int SECOND = 1;
  public static final int MINUTE = 60;
  public static final int HOUR = 3600;
  public static final int DAY = 86400;
  public static final int WEEK = 604800;
  public static final int MONTH_30_DAYS = 2592000;
  public static final int YEAR = 31536000;

  public static final String TIME_PATTERN_REGEX = "^(\\d+)([smhdwMy])$";
  public static final String REDIS_ALL_TIME_KEY = "songs:alltime";
  public static final String REDIS_REALTIME_KEY_PREFIX = "songs:realtime:";
  public static final String REDIS_HOURLY_KEY_PREFIX = "songs:hourly:";
  public static final String REDIS_DAILY_KEY_PREFIX = "songs:daily:";

  public static final String CASSANDRA_ALL_TIME_BUCKET = "alltime";
  public static final String CASSANDRA_HOURLY_BUCKET_PREFIX = "hourly_";
  public static final String CASSANDRA_DAILY_BUCKET_PREFIX = "daily_";
  public static final String CASSANDRA_MONTHLY_BUCKET_PREFIX = "monthly_";
}
