require 'redis'
require "redis_lock/version"

class RedisLock
  attr_reader :key

  def self.config
    @config ||= Configuration.new
  end

  def self.setup
    yield config
  end

  def self.semaphore(key, args = {}, &block)
    new(key, instance_args(args)).semaphore(args, &block)
  end

  def self.if_open(key, args = {}, &block)
    new(key, instance_args(args)).if_open(args, &block)
  end

  def self.if_locked(key, args = {}, &block)
    new(key, instance_args(args)).if_locked(args, &block)
  end

  def config; self.class.config; end

  def initialize(key, opts = {})
    @key = "REDISLOCK::#{key}"
    @redis = opts[:redis]
  end

  def redis
    @redis ||= config.redis
  end

  # Redis SET options:
  # - EX seconds -- Set the specified expire time, in seconds.
  # - PX milliseconds -- Set the specified expire time, in milliseconds.
  # - NX -- Only set the key if it does not already exist.
  # - XX -- Only set the key if it already exist.
  def set(expiration_time = 60, opts = {})
    value = opts.delete(:value) || Time.now.strftime('%FT%T')
    args = if opts[:px]
             { px: expiration_time }
           else
             { ex: expiration_time }
           end
    redis.set(key, value, args.merge(opts)) == "OK" ? true : false
  end

  def semaphore(args = {}, &block)
    Semaphore.new(self, args).call(&block)
  end

  def if_open(args = {}, &block)
    IfOpen.new(self, args).call(&block)
  end
  alias_method :perform, :if_open

  def if_locked(args = {}, &block)
    IfLocked.new(self, args).call(&block)
  end

  def locked?
    ttl == -2 ? false : true
  end
  alias_method :exists?, :locked?
  alias_method :in_use?, :locked?

  def ttl
    redis.ttl(key)
  end

  def open?
    !locked?
  end
  alias_method :unlocked?, :open?

  def delete
    redis.del(key) == 1 ? true : false
  end
  alias_method :unlock!, :delete
  alias_method :open!, :delete
  alias_method :remove, :delete

  def value
    redis.get(key)
  end

  def self.instance_args(args)
    allowed = [:redis]
    args.select { |k, _v| allowed.include?(k) }.compact
  end

  # def self.setup_instance(key, args)
  #   inst_opts = { redis: args.delete(:redis) }.reject{ |_, v| v.nil? }
  #   new(key, inst_opts)
  # end
end
require "redis_lock/configuration"
require "redis_lock/semaphore"
require "redis_lock/if_open"
require "redis_lock/if_locked"
require "redis_lock/multi_lock"
