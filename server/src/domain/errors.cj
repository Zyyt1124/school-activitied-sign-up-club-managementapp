package campus.domain

/**
 * 业务错误。code 是给端侧做分支判断的稳定标识，detail 才是给人看的文案。
 *
 * 示例：
 *   NO_SEAT           名额已满
 *   ALREADY_SIGNED    已经报名
 *   NOT_IN_SIGN_PERIOD 不在报名时段
 *   FORBIDDEN          越权操作
 */
public class BizError <: Exception {
    public let code: String
    public let status: Int64
    public let detail: String

    public init(code: String, message: String, status: Int64) {
        super(message)
        this.code = code
        this.status = status
        this.detail = message
    }
}

public func notFoundError(code: String, message: String): BizError {
    return BizError(code, message, 404)
}

public func conflictError(code: String, message: String): BizError {
    return BizError(code, message, 409)
}

public func forbiddenError(code: String, message: String): BizError {
    return BizError(code, message, 403)
}

public func invalidError(code: String, message: String): BizError {
    return BizError(code, message, 400)
}

public func unauthorizedError(code: String, message: String): BizError {
    return BizError(code, message, 401)
}
