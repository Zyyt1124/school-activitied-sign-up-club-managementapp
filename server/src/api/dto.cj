package campus.api

import std.collection.*
import campus.domain.*

/**
 * 端云契约的唯一权威实现。
 *
 * ArkTS 侧的 models.ets 与这里的字段一一对应；HTTP 适配器只负责
 * 反序列化请求、调用 facade、把 DTO 的 toJson() 写回响应。
 */

public func jsonEscape(value: String): String {
    return value
        .replace("\\", "\\\\")
        .replace("\"", "\\\"")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
}

public func jsonString(value: String): String {
    return "\"${jsonEscape(value)}\""
}

public func jsonBool(value: Bool): String {
    match (value) {
        case true => "true"
        case false => "false"
    }
}

public class UserDto {
    public let userId: Int64
    public let studentId: String
    public let name: String
    public let role: String
    public let college: String

    public init(userId: Int64, studentId: String, name: String, role: String, college: String) {
        this.userId = userId
        this.studentId = studentId
        this.name = name
        this.role = role
        this.college = college
    }

    public func toJson(): String {
        return "{\"userId\":${userId},\"studentId\":${jsonString(studentId)},\"name\":${jsonString(name)},\"role\":${jsonString(role)},\"college\":${jsonString(college)}}"
    }
}

public class LoginResponseDto {
    public let token: String
    public let user: UserDto

    public init(token: String, user: UserDto) {
        this.token = token
        this.user = user
    }

    public func toJson(): String {
        return "{\"token\":${jsonString(token)},\"user\":${user.toJson()}}"
    }
}

public class ActivitySummaryDto {
    public let activityId: Int64
    public let clubId: Int64
    public let clubName: String
    public let title: String
    public let location: String
    public let state: String
    public let remainCount: Int64
    public let maxCount: Int64
    public let signStart: Int64
    public let signEnd: Int64
    public let activityTime: Int64

    public init(
        activityId: Int64,
        clubId: Int64,
        clubName: String,
        title: String,
        location: String,
        state: String,
        remainCount: Int64,
        maxCount: Int64,
        signStart: Int64,
        signEnd: Int64,
        activityTime: Int64
    ) {
        this.activityId = activityId
        this.clubId = clubId
        this.clubName = clubName
        this.title = title
        this.location = location
        this.state = state
        this.remainCount = remainCount
        this.maxCount = maxCount
        this.signStart = signStart
        this.signEnd = signEnd
        this.activityTime = activityTime
    }

    public func toJson(): String {
        return "{\"activityId\":${activityId},\"clubId\":${clubId},\"clubName\":${jsonString(clubName)},\"title\":${jsonString(title)},\"location\":${jsonString(location)},\"state\":${jsonString(state)},\"remainCount\":${remainCount},\"maxCount\":${maxCount},\"signStart\":${signStart},\"signEnd\":${signEnd},\"activityTime\":${activityTime}}"
    }
}

public class ActivityDetailDto {
    public let activityId: Int64
    public let clubId: Int64
    public let clubName: String
    public let title: String
    public let description: String
    public let location: String
    public let state: String
    public let remainCount: Int64
    public let maxCount: Int64
    public let signStart: Int64
    public let signEnd: Int64
    public let activityTime: Int64
    public let signed: Bool

    public init(
        activityId: Int64,
        clubId: Int64,
        clubName: String,
        title: String,
        description: String,
        location: String,
        state: String,
        remainCount: Int64,
        maxCount: Int64,
        signStart: Int64,
        signEnd: Int64,
        activityTime: Int64,
        signed: Bool
    ) {
        this.activityId = activityId
        this.clubId = clubId
        this.clubName = clubName
        this.title = title
        this.description = description
        this.location = location
        this.state = state
        this.remainCount = remainCount
        this.maxCount = maxCount
        this.signStart = signStart
        this.signEnd = signEnd
        this.activityTime = activityTime
        this.signed = signed
    }

    public func toJson(): String {
        return "{\"activityId\":${activityId},\"clubId\":${clubId},\"clubName\":${jsonString(clubName)},\"title\":${jsonString(title)},\"description\":${jsonString(description)},\"location\":${jsonString(location)},\"state\":${jsonString(state)},\"remainCount\":${remainCount},\"maxCount\":${maxCount},\"signStart\":${signStart},\"signEnd\":${signEnd},\"activityTime\":${activityTime},\"signed\":${jsonBool(signed)}}"
    }
}

public class ActivityListDto {
    public let items: ArrayList<ActivitySummaryDto>
    public let nextCursor: String

    public init(items: ArrayList<ActivitySummaryDto>, nextCursor: String) {
        this.items = items
        this.nextCursor = nextCursor
    }

    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{\"items\":[")
        var first = true
        for (item in items) {
            if (!first) {
                sb.append(",")
            }
            sb.append(item.toJson())
            first = false
        }
        sb.append("],\"nextCursor\":")
        sb.append(jsonString(nextCursor))
        sb.append("}")
        return sb.toString()
    }
}

public class SignUpReceiptDto {
    public let signId: Int64
    public let activityId: Int64
    public let userId: Int64
    public let signTime: Int64
    public let remainCount: Int64

    public init(
        signId: Int64,
        activityId: Int64,
        userId: Int64,
        signTime: Int64,
        remainCount: Int64
    ) {
        this.signId = signId
        this.activityId = activityId
        this.userId = userId
        this.signTime = signTime
        this.remainCount = remainCount
    }

    public func toJson(): String {
        return "{\"signId\":${signId},\"activityId\":${activityId},\"userId\":${userId},\"signTime\":${signTime},\"remainCount\":${remainCount}}"
    }
}

public class ClubDto {
    public let clubId: Int64
    public let clubName: String
    public let intro: String
    public let leaderId: Int64
    public let status: String

    public init(clubId: Int64, clubName: String, intro: String, leaderId: Int64, status: String) {
        this.clubId = clubId
        this.clubName = clubName
        this.intro = intro
        this.leaderId = leaderId
        this.status = status
    }

    public func toJson(): String {
        return "{\"clubId\":${clubId},\"clubName\":${jsonString(clubName)},\"intro\":${jsonString(intro)},\"leaderId\":${leaderId},\"status\":${jsonString(status)}}"
    }
}

public class ClubListDto {
    public let items: ArrayList<ClubDto>

    public init(items: ArrayList<ClubDto>) {
        this.items = items
    }

    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{\"items\":[")
        var first = true
        for (item in items) {
            if (!first) {
                sb.append(",")
            }
            sb.append(item.toJson())
            first = false
        }
        sb.append("]}")
        return sb.toString()
    }
}

public class MessageDto {
    public let messageId: Int64
    public let title: String
    public let content: String
    public let messageType: String
    public let read: Bool
    public let createdAt: Int64

    public init(
        messageId: Int64,
        title: String,
        content: String,
        messageType: String,
        read: Bool,
        createdAt: Int64
    ) {
        this.messageId = messageId
        this.title = title
        this.content = content
        this.messageType = messageType
        this.read = read
        this.createdAt = createdAt
    }

    public func toJson(): String {
        return "{\"messageId\":${messageId},\"title\":${jsonString(title)},\"content\":${jsonString(content)},\"messageType\":${jsonString(messageType)},\"read\":${jsonBool(read)},\"createdAt\":${createdAt}}"
    }
}

public class MessageListDto {
    public let items: ArrayList<MessageDto>

    public init(items: ArrayList<MessageDto>) {
        this.items = items
    }

    public func toJson(): String {
        let sb = StringBuilder()
        sb.append("{\"items\":[")
        var first = true
        for (item in items) {
            if (!first) {
                sb.append(",")
            }
            sb.append(item.toJson())
            first = false
        }
        sb.append("]}")
        return sb.toString()
    }
}

public class ErrorDto {
    public let code: String
    public let message: String
    public let requestId: String

    public init(code: String, message: String, requestId: String) {
        this.code = code
        this.message = message
        this.requestId = requestId
    }

    public func toJson(): String {
        return "{\"code\":${jsonString(code)},\"message\":${jsonString(message)},\"requestId\":${jsonString(requestId)}}"
    }
}

// ---- domain -> DTO ----

public func toUserDto(user: User): UserDto {
    return UserDto(user.userId, user.studentId, user.name, roleValue(user.role), user.college)
}

public func toActivitySummaryDto(activity: Activity, clubName: String): ActivitySummaryDto {
    return ActivitySummaryDto(
        activity.activityId,
        activity.clubId,
        clubName,
        activity.title,
        activity.location,
        activityStateValue(activity.state),
        activity.remainCount,
        activity.maxCount,
        activity.signStart,
        activity.signEnd,
        activity.activityTime
    )
}

public func toActivityDetailDto(activity: Activity, clubName: String, signed: Bool): ActivityDetailDto {
    return ActivityDetailDto(
        activity.activityId,
        activity.clubId,
        clubName,
        activity.title,
        activity.description,
        activity.location,
        activityStateValue(activity.state),
        activity.remainCount,
        activity.maxCount,
        activity.signStart,
        activity.signEnd,
        activity.activityTime,
        signed
    )
}

public func toSignUpReceiptDto(receipt: SignUpReceipt): SignUpReceiptDto {
    return SignUpReceiptDto(
        receipt.signId,
        receipt.activityId,
        receipt.userId,
        receipt.signTime,
        receipt.remainCount
    )
}

public func toClubDto(club: Club): ClubDto {
    return ClubDto(club.clubId, club.clubName, club.intro, club.leaderId, clubStatusValue(club.status))
}

public func toMessageDto(message: Message): MessageDto {
    return MessageDto(
        message.messageId,
        message.title,
        message.content,
        message.messageType,
        message.read,
        message.createdAt
    )
}
