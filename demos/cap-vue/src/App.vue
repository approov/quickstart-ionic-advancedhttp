<template>
  <ion-app>
    <ion-header>
      <ion-toolbar>
        <ion-title class="ion-text-center">Approov Vue</ion-title>
      </ion-toolbar>
    </ion-header>

    <ion-content>
      <ion-grid style="height: 100%">
        <ion-row
            class="ion-justify-content-center ion-align-items-center"
            style="height: calc(100% - 80px); flex-direction: column"
        >
          <div class="ion-text-center">
            <img :src="imageUrl">
            <ion-spinner v-if="isLoading" name="crescent"></ion-spinner>
            <p>{{ message }}</p>
          </div>
        </ion-row>
        <ion-row>
          <ion-col>
            <div class="button__container">
              <ion-button class="button__container--hello" @click="onHelloClick()">Hello</ion-button>
              <ion-button class="button__container--shape" @click="onShapeClick()">Shape</ion-button>
            </div>
          </ion-col>
        </ion-row>
      </ion-grid>
    </ion-content>
  </ion-app>
</template>

<style scoped>
.button__container {
  margin: 0 50px;
}

.button__container--shape {
  float: right;
}
</style>

<script lang="ts">
import {
  IonApp,
  IonCol,
  IonContent,
  IonGrid,
  IonRow,
  IonTitle,
  IonToolbar,
  IonHeader
} from '@ionic/vue';
import {defineComponent} from 'vue';

// COMMENT WHEN USING APPROOV
import { HTTP, HTTPResponse } from '@awesome-cordova-plugins/http';

// UNCOMMENT WHEN USING APPROOV
//import { HTTP, HTTPResponse } from '@awesome-cordova-plugins/approov-advanced-http';

const HOST = 'https://shapes.approov.io';
const imageBaseUrl = './assets/';
const imageExtension = 'png';

// ChANGE TO v3 FOR APPROOV API PROTECTION; SHOULD BE v1 OTHERWISE
const VERSION = 'v1' as string;

const HELLO_URL = `${HOST}/v1/hello`;
const SHAPE_URL = `${HOST}/${VERSION}/shapes`;

// COMMENT IF USING APPOROV WITH SECRETS PROTECTION
const API_KEY = `yXClypapWNHIifHUWmBIyPFAm`;

// UNCOMMENT IF USING APPOROV WITH SECRETS PROTECTION
//const API_KEY = `shapes_api_key_placeholder`;

export default defineComponent({
  name: 'App',
  components: {
    IonApp,
    IonContent,
    IonTitle,
    IonToolbar,
    IonGrid,
    IonRow,
    IonCol,
    IonHeader
  },
  data() {
    return {
      imageUrl: this.getImageUrl('approov'),
      message: 'Tap Hello to Start...',
      isLoading: false,
    };
  },

  created() {
      // UNCOMMENT IF USING APPROOV
      //HTTP.approovInitialize("<enter-your-config-string-here>");

      // UNCOMMENT IF USING APPROOV SECRETS PROTECTION
      //HTTP.approovAddSubstitutionHeader("Api-Key", "");
  },

  methods: {
    async onHelloClick() {
      this.presentLoadingIndicator();
      try {
        const response = await HTTP.get(HELLO_URL, {}, {});
        this.hideLoadingIndicator();
        const data = JSON.parse(response.data);
        this.message = data.text;
        this.imageUrl = this.getImageUrl('hello');
      } catch (err) {
        this.onAPIError(err as HTTPResponse);
      }
    },

    async onShapeClick() {
      this.presentLoadingIndicator();
      try {
        const response = await HTTP.get(SHAPE_URL, {}, {'Api-Key': API_KEY});
        this.hideLoadingIndicator();
        const data = JSON.parse(response.data);
        this.message = data.status;
        this.imageUrl = this.getImageUrl(data.shape.toLowerCase());
      } catch (err) {
        this.onAPIError(err as HTTPResponse);
      }
    },

    getImageUrl(name: string): string {
      return `${imageBaseUrl}${name}.${imageExtension}`;
    },

    presentLoadingIndicator() {
      this.isLoading = true;
      this.imageUrl = this.getImageUrl('approov');
      this.message = 'Fetching Data.....';
    },

    onAPIError(err: HTTPResponse) {
      this.hideLoadingIndicator();
      let message: string;
      try {
        const error = JSON.parse(err.error as string);
        message = `Status Code: ${err.status}, ${error.status}`;
      } catch {
        message = `Status Code: ${err.status}, ${err.error}`;
      }

      this.message = message;
      this.imageUrl = this.getImageUrl('confused');
    },

    hideLoadingIndicator() {
      this.isLoading = false;
    }
  },
});
</script>
