<template>
  <ion-app>
    <ion-toolbar class="ion-text-center">
      <ion-title>Approov Vue Demo</ion-title>
    </ion-toolbar>

    <ion-content>
      <ion-grid style="height: 100%">
        <ion-row
            class="ion-justify-content-center ion-align-items-center"
            style="height: calc(100% - 80px); flex-direction: column"
        >
          <div class="ion-text-center">
            <ion-img :src="imageUrl" style="margin: 0 30px"></ion-img>
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
  IonToolbar
} from '@ionic/vue';
import {defineComponent} from 'vue';
import {HTTP, HTTPResponse} from '@ionic-native/http';

const imageBaseUrl = 'assets/';
const imageExtension = 'png';
const VERSION = 'v2'; // Change To v2 when using Approov
const HELLO_URL = `https://shapes.approov.io/v1/hello`;
const SHAPE_URL = `https://shapes.approov.io/${VERSION}/shapes`;

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
  },
  data() {
    return {
      imageUrl: this.getImageUrl('approov'),
      message: 'Tap Hello to Start...',
      isLoading: false,
    };
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
        this.onAPIError(err);
      }
    },

    async onShapeClick() {
      this.presentLoadingIndicator();
      try {
        const response = await HTTP.get(SHAPE_URL, {}, {});
        this.hideLoadingIndicator();
        const data = JSON.parse(response.data);
        this.message = data.status;
        this.imageUrl = this.getImageUrl(data.shape.toLowerCase());
      } catch (err) {
        this.onAPIError(err);
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
      const error = JSON.parse(err.error as any);
      this.message = `Status Code: ${err.status}, ${error.status}`;
      this.imageUrl = this.getImageUrl('confused');
    },

    hideLoadingIndicator() {
      this.isLoading = false;
    }
  },
});
</script>
