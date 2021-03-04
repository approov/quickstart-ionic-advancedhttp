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
import { HTTP, HTTPResponse } from "@ionic-native/http";

interface AppState {
  message: string;
  imageUrl: string;
  isLoading: boolean;
}

export class App extends Component<any, AppState> {
  private http = HTTP;
  readonly imageBaseUrl = "assets/";
  readonly imageExtension = "png";
  readonly VERSION = "v2"; // Change To v2 when using Approov
  readonly HELLO_URL = `https://shapes.approov.io/v1/hello`;
  readonly SHAPE_URL = `https://shapes.approov.io/${this.VERSION}/shapes`;

  constructor(props: any) {
    super(props);
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
    } catch (err) {
      this.onAPIError(err);
    }
  }

  async onShapeClick() {
    this.presentLoadingIndicator();
    try {
      const response = await this.http.get(this.SHAPE_URL, {}, {});
      this.hideLoadingIndicator();
      const data = JSON.parse(response.data);
      this.setState({
        message: data.status,
        imageUrl: this.getImageUrl(data.shape.toLowerCase()),
      });
    } catch (err) {
      this.onAPIError(err);
    }
  }

  getImageUrl(name: string): string {
    return `${this.imageBaseUrl}${name}.${this.imageExtension}`;
  }

  private onAPIError(err: HTTPResponse) {
    this.hideLoadingIndicator();
    const error = JSON.parse(err.error as any);
    this.setState({
      message: `Status Code: ${err.status}, ${error.status}`,
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
        <IonToolbar>
          <IonTitle>Approov React Demo</IonTitle>
        </IonToolbar>

        <IonContent>
          <IonGrid className="full-height">
            <IonRow className="ion-justify-content-center ion-align-items-center container">
              <div className="ion-text-center">
                <IonImg className="image" src={this.state.imageUrl} />
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
