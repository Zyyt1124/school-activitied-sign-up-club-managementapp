import { router } from '@kit.ArkUI';
import { AppColors, AppSpace, AppText } from '../common/constants/AppTheme';
import { ApiClient, ApiError } from '../common/api/ApiClient';
import { SessionStore } from '../common/auth/SessionStore';
import { LoginRequest, LoginResponse } from '../common/models';

@Entry
@Component
struct Login {
  @State studentId: string = '';
  @State password: string = '';
  @State loading: boolean = false;
  @State errorMessage: string = '';

  private async onLogin(): Promise<void> {
    const studentId = this.studentId.trim();
    if (studentId.length === 0 || this.password.length === 0) {
      this.errorMessage = '请输入学号和密码';
      return;
    }

    this.loading = true;
    this.errorMessage = '';
    try {
      const body: LoginRequest = {
        studentId: studentId,
        password: this.password
      };
      const result = await ApiClient.post<LoginResponse>('/auth/login', body);
      ApiClient.setToken(result.token);
      await SessionStore.save(result.token, result.user);
      router.replaceUrl({ url: 'pages/Main' });
    } catch (error) {
      const apiError = error as ApiError;
      this.errorMessage = apiError.message !== undefined ? apiError.message : '登录失败，请稍后重试';
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Text('校园活动与社团管理')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.ink)
          .width('100%')
        Text('学生、社团负责人、管理员，一个账号进入自己的视角')
          .fontSize(AppText.caption)
          .fontColor(AppColors.muted)
          .width('100%')
      }
      .width('100%')
      .margin({ top: 72, bottom: 40 })

      Column({ space: 14 }) {
        TextInput({ placeholder: '学号', text: this.studentId })
          .height(52)
          .fontSize(AppText.body)
          .backgroundColor(AppColors.white)
          .borderRadius(10)
          .onChange((value: string) => {
            this.studentId = value;
          })

        TextInput({ placeholder: '密码', text: this.password })
          .type(InputType.Password)
          .height(52)
          .fontSize(AppText.body)
          .backgroundColor(AppColors.white)
          .borderRadius(10)
          .onChange((value: string) => {
            this.password = value;
          })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(AppText.caption)
            .fontColor(AppColors.danger)
            .width('100%')
        }

        Button(this.loading ? '登录中…' : '登录')
          .width('100%')
          .height(50)
          .fontSize(AppText.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.white)
          .backgroundColor(AppColors.blue)
          .borderRadius(10)
          .enabled(!this.loading)
          .onClick(() => {
            this.onLogin();
          })
      }
      .width('100%')

      Blank()

      Text('演示阶段：账号由校园统一身份认证模拟，密码不落库明文。')
        .fontSize(11)
        .fontColor(AppColors.muted)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppSpace.page, right: AppSpace.page })
    .backgroundColor(AppColors.bg)
  }
}
