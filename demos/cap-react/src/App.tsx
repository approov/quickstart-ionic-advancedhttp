import {
  IonApp,
  IonToolbar,
  IonTitle,
  IonContent,
  IonGrid,
  IonRow,
  IonCol,
  IonImg,
  IonSpinner,
  IonButton,
  IonHeader,
  setupIonicReact,
} from "@ionic/react";

/* Core CSS required for Ionic components to work properly */
import "@ionic/react/css/core.css";

/* Basic CSS for apps built with Ionic */
import "@ionic/react/css/normalize.css";
import "@ionic/react/css/structure.css";
import "@ionic/react/css/typography.css";

/* Optional CSS utils that can be commented out */
import "@ionic/react/css/padding.css";
import "@ionic/react/css/float-elements.css";
import "@ionic/react/css/text-alignment.css";
import "@ionic/react/css/text-transformation.css";
import "@ionic/react/css/flex-utils.css";
import "@ionic/react/css/display.css";

/* Theme variables */
import "./theme/variables.css";
import { Component } from "react";

// COMMENT WHEN USING APPROOV
import { HTTP, HTTPResponse } from "@awesome-cordova-plugins/http";

// UNCOMMENT WHEN USING APPROOV
//import { HTTP, HTTPResponse } from "@awesome-cordova-plugins/approov-advanced-http";

import React from "react";

interface AppState {
  message: string;
  imageUrl: string;
  isLoading: boolean;
}

setupIonicReact();

export class App extends Component<any, AppState> {
  private http = HTTP;
  readonly host = "https://shapes.approov.io";
  readonly imageBaseUrl = "./assets/";
  readonly imageExtension = "png";

  // CHANGE TO v3 FOR APPROOV WITH API PROTECTION; USE v1 FOR APPROOV WITH SECRETS PROTECTION
  readonly VERSION: string = 'v1'; 

  readonly HELLO_URL = `${this.host}/v1/hello`;
  readonly SHAPE_URL = `${this.host}/${this.VERSION}/shapes`;

  // COMMENT IF USING APPOROV WITH SECRETS PROTECTION
  readonly API_KEY = `yXClypapWNHIifHUWmBIyPFAm`;

  // UNCOMMENT IF USING APPOROV WITH SECRETS PROTECTION
  //readonly API_KEY = `shapes_api_key_placeholder`;

  constructor(props: any) {
    super(props);

    // UNCOMMENT IF USING APPROOV
    //this.http.approovInitialize("<enter-your-config-string-here>");

    // UNCOMMENT IF USING APPROOV SECRETS PROTECTION
    //this.http.approovAddSubstitutionHeader("Api-Key", "");

    this.state = {
      message: "Tap Hello to Start...",
      isLoading: false,
      imageUrl: this.getImageUrl("approov"),
    };
  }

  async onHelloClick() {
    this.presentLoadingIndicator();
    try {
      const response = await this.http.get(this.HELLO_URL, {}, {});
      this.hideLoadingIndicator();
      const data = JSON.parse(response.data);
      this.setState({
        message: data.text,
        imageUrl: this.getImageUrl("hello"),
      });
    } catch (err: any) {
      this.onAPIError(err);
    }
  }

  async onShapeClick() {
    this.presentLoadingIndicator();
    try {
      const response = await this.http.get(this.SHAPE_URL, {}, {'Api-Key': this.API_KEY});
      this.hideLoadingIndicator();
      const data = JSON.parse(response.data);
      this.setState({
        message: data.status,
        imageUrl: this.getImageUrl(data.shape.toLowerCase()),
      });
    } catch (err: any) {
      this.onAPIError(err);
    }
  }

  getImageUrl(name: string): string {
    return `${this.imageBaseUrl}${name}.${this.imageExtension}`;
  }

  private onAPIError(err: HTTPResponse) {
    this.hideLoadingIndicator();
    let message: string;
    try {
      const error = JSON.parse(err.error as string);
      message = `Status Code: ${err.status}, ${error.status}`;
    } catch {
      message = `Status Code: ${err.status}, ${err.error}`;
    }

    this.setState({
      message,
      imageUrl: this.getImageUrl("confused"),
    });
  }

  private presentLoadingIndicator() {
    this.setState({
      isLoading: true,
      imageUrl: this.getImageUrl("approov"),
      message: "Fetching Data.....",
    });
  }

  private hideLoadingIndicator() {
    this.setState({ isLoading: false });
  }

  render() {
    return (
      <IonApp>
        <IonHeader>
          <IonToolbar>
            <IonTitle className="ion-text-center">Approov React</IonTitle>
          </IonToolbar>
        </IonHeader>

        <IonContent>
          <IonGrid className="ion-align-items-stretch">
            <IonRow className="ion-justify-content-center ion-align-items-center container">
              <div className="ion-text-center">
                <img className="image" src={this.state.imageUrl} />
                {this.state.isLoading && <IonSpinner name="crescent" />}
                <p>{this.state.message}</p>
              </div>
            </IonRow>
            <IonRow>
              <IonCol>
                <div className="button__container">
                  <IonButton
                    className="button__container--hello"
                    onClick={this.onHelloClick.bind(this)}
                  >
                    Hello
                  </IonButton>
                  <IonButton
                    className="button__container--shape"
                    onClick={this.onShapeClick.bind(this)}
                  >
                    Shape
                  </IonButton>
                </div>
              </IonCol>
            </IonRow>
          </IonGrid>
        </IonContent>
      </IonApp>
    );
  }
}

export default App;
