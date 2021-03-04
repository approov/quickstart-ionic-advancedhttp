declare module "*.vue" {
  import { defineComponent } from "vue";
  const component: ReturnType<typeof defineComponent>;
  export default component;
}

export interface AppState {
  message: string;
  imageUrl: string;
  isLoading: boolean;
}
