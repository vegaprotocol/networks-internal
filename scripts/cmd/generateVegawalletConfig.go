package cmd

import (
	"fmt"
	"log"
	"os"
	"path"
	"sort"

	"github.com/spf13/cobra"
	"github.com/tomwright/dasel"
	"github.com/tomwright/dasel/storage"
	"go.uber.org/zap"
)

type GenerateVegawalletConfigArgs struct {
	RootArgs
	DataNodeIds []string
}

var generateVegawalletConfigArgs GenerateVegawalletConfigArgs

var generateVegawalletConfigCmd = &cobra.Command{
	Use:   "generate-vegawallet-config",
	Short: "Generate vegawallet config for network",
	Run: func(cmd *cobra.Command, args []string) {
		generateVegawalletConfigArgs.RootArgs = rootArgs
		if err := RunGenerateVegawalletConfig(generateVegawalletConfigArgs); err != nil {
			rootArgs.Logger.Error("Error", zap.Error(err))
			os.Exit(1)
		}
	},
}

func init() {
	rootCmd.AddCommand(generateVegawalletConfigCmd)

	generateVegawalletConfigCmd.PersistentFlags().StringSliceVar(&generateVegawalletConfigArgs.DataNodeIds, "data-node-ids", nil, "Comma separated list of Data Nodes, e.g. n01,n04,n12")
	if err := generateVegawalletConfigCmd.MarkPersistentFlagRequired("data-node-ids"); err != nil {
		log.Fatalf("%v\n", err)
	}
}

type vegawalletConfig struct {
	Name        string
	Level       string
	TokenExpiry string
	Port        uint64
	Host        string

	API struct {
		GRPC struct {
			Hosts   []string
			Retries uint16
		}
		REST struct {
			Hosts []string
		}
		GraphQL struct {
			Hosts []string
		}
	}
	TokenDApp struct {
		URL       string
		LocalPort uint64
	}
	Console struct {
		URL       string
		LocalPort uint64
	}
}

func RunGenerateVegawalletConfig(args GenerateVegawalletConfigArgs) error {
	// Prepare new config
	data := vegawalletConfig{
		Name:        args.VegaNetworkName,
		Level:       "info",
		TokenExpiry: "168h0m0s",
		Port:        1789,
		Host:        "127.0.0.1",
	}

	data.API.GRPC.Hosts = append(data.API.GRPC.Hosts, fmt.Sprintf("api.%s.vega.xyz:3007", args.VegaNetworkName))
	data.API.REST.Hosts = append(data.API.REST.Hosts, fmt.Sprintf("https://api.%s.vega.xyz", args.VegaNetworkName))
	data.API.GraphQL.Hosts = append(data.API.GraphQL.Hosts, fmt.Sprintf("https://api.%s.vega.xyz/graphql/", args.VegaNetworkName))

	// sort node ids - to minimise changes to generated config
	sort.Strings(args.DataNodeIds)

	for _, nodeId := range args.DataNodeIds {
		data.API.GRPC.Hosts = append(data.API.GRPC.Hosts, fmt.Sprintf("api.%s.%s.vega.xyz:3007", nodeId, args.VegaNetworkName))
		data.API.REST.Hosts = append(data.API.REST.Hosts, fmt.Sprintf("https://api.%s.%s.vega.xyz", nodeId, args.VegaNetworkName))
		data.API.GraphQL.Hosts = append(data.API.GraphQL.Hosts, fmt.Sprintf("https://api.%s.%s.vega.xyz/graphql/", nodeId, args.VegaNetworkName))
	}
	data.API.GRPC.Retries = 5
	data.Console.URL = "" // fmt.Sprintf("%s.vega.trading", args.VegaNetworkName)
	data.Console.LocalPort = 1847
	data.TokenDApp.URL = "" // fmt.Sprintf("%s.token.vega.xyz", args.VegaNetworkName)
	data.TokenDApp.LocalPort = 1848

	// Store new config
	currPath, err := os.Getwd()
	if err != nil {
		return err
	}
	generatedVegawalletConfigPath := path.Join(currPath, args.VegaNetworkName, fmt.Sprintf("vegawallet-%s.toml", args.VegaNetworkName))

	config := dasel.New(data)

	if err := config.WriteToFile(generatedVegawalletConfigPath, "toml", []storage.ReadWriteOption{}); err != nil {
		return err
	}

	return nil
}
