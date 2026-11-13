/**
 * 端云边界只有一个出口：ApiClient。
 *
 * 本地联调：
 *  - 模拟器访问宿主机一般用 10.0.2.2
 *  - 真机联调改成电脑局域网 IP，例如 http://192.168.1.20:8080/v1
 *  - 生产环境必须使用 HTTPS
 */
export class ApiConfig {
  static readonly baseUrl: string = 'http://10.0.2.2:8080/v1';
  static readonly connectTimeoutMs: number = 10000;
  static readonly readTimeoutMs: number = 10000;
}
