package campus.domain

import std.time.*

public interface Clock {
    func nowMillis(): Int64
}

public class SystemClock <: Clock {
    public func nowMillis(): Int64 {
        return DateTime.now().toUnixTimeStamp().toMilliseconds()
    }
}

/**
 * 固定时钟用于测试。时间作为依赖注入，业务逻辑不直接读系统时间。
 */
public class FixedClock <: Clock {
    private var value: Int64

    public init(value: Int64) {
        this.value = value
    }

    public func nowMillis(): Int64 {
        return value
    }

    public func set(value: Int64): Unit {
        this.value = value
    }
}
