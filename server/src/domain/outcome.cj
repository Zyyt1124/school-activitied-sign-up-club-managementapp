package campus.domain

/**
 * 业务层统一返回值。
 *
 * 仓颉标准库没有内置 Result，这里用带泛型的 enum 表达「成功/失败」，
 * 让调用方必须显式处理错误分支，而不是靠返回 null 或抛异常。
 */
public enum Outcome<T, E> {
    | Ok(T)
    | Err(E)

    public func isOk(): Bool {
        match (this) {
            case Ok(_) => true
            case Err(_) => false
        }
    }

    public func isErr(): Bool {
        match (this) {
            case Ok(_) => false
            case Err(_) => true
        }
    }

    public func unwrapOr(fallback: T): T {
        match (this) {
            case Ok(value) => value
            case Err(_) => fallback
        }
    }

    public func map<U>(transform: (T) -> U): Outcome<U, E> {
        match (this) {
            case Ok(value) => Ok(transform(value))
            case Err(error) => Err(error)
        }
    }
}

/**
 * 显式指定成功类型的构造器。
 *
 * 在闭包 / match 分支里，编译器有时无法从上下文反推出 Ok/Err 的 T，
 * 用这两个 helper 把类型写清楚，也避免在业务代码里重复写泛型实参。
 */
public func succeed<T>(value: T): Outcome<T, BizError> {
    return Ok(value)
}

public func fail<T>(error: BizError): Outcome<T, BizError> {
    return Err(error)
}
